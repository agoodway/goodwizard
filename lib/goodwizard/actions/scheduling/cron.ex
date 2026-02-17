defmodule Goodwizard.Actions.Scheduling.Cron do
  @moduledoc """
  Schedules a recurring task on a cron expression.

  Validates the cron expression and registers the job directly with
  `Jido.Scheduler.run_every`, bypassing the executor's directive pipeline.
  The scheduler pid is tracked in `CronRegistry` for later cancellation.

  ## Delivery Targeting

  Jobs are addressed to a **channel** (e.g. `"telegram"`) and an
  **external_id** (e.g. a Telegram chat_id) rather than a Messaging room
  UUID. The room is resolved at delivery time, which survives app restarts
  that wipe the in-memory ETS room store.

  ## Execution Modes

  - `"isolated"` (default) — each cron tick spawns a child agent with its own
    context window. Supports an optional `model` override.
  - `"main"` — cron tick is dispatched inline through the main agent pipeline
    (legacy behavior). The `model` parameter is ignored in this mode.
  """

  use Jido.Action,
    name: "schedule_cron_task",
    description:
      ~s[Schedule a recurring task using a cron expression. ] <>
        ~s[Supports standard 5-field cron (minute hour day month weekday), ] <>
        ~s[aliases (@daily, @hourly, @weekly, @monthly, @yearly), ] <>
        ~s[and extended expressions. Examples: "0 9 * * *" (daily at 9am), ] <>
        ~s["*/5 * * * *" (every 5 minutes), "0 9 * * MON" (Mondays at 9am). ] <>
        ~s[Optional mode: "isolated" (default, runs in child agent) or "main" (inline). ] <>
        ~s[Optional model: override the LLM model for isolated mode.],
    schema: [
      schedule: [type: :string, required: true, doc: "Cron expression (e.g. \"0 9 * * *\")"],
      task: [type: :string, required: true, doc: "Description of the task to execute"],
      channel: [
        type: :string,
        required: false,
        doc:
          "Delivery channel (e.g. \"telegram\", \"cli\"). Auto-resolved from agent context when omitted."
      ],
      external_id: [
        type: :string,
        required: false,
        doc:
          "Channel-specific target ID (e.g. Telegram chat_id). Auto-resolved from agent context when omitted."
      ],
      mode: [
        type: :string,
        required: false,
        doc: "Execution mode: \"isolated\" (default) or \"main\""
      ],
      model: [
        type: :string,
        required: false,
        doc: "LLM model override for isolated mode (e.g. \"anthropic:claude-haiku-4-5\")"
      ]
    ]

  require Logger

  alias Goodwizard.Scheduling.{CronRegistry, CronStore}

  @valid_modes ~w(main isolated)
  @known_model_prefixes ~w(anthropic: openai: google: ollama: mistral:)

  # Standard 5-field cron has a minimum resolution of 1 minute.
  # Warn on every-minute schedules to flag potential resource abuse.
  @high_frequency_patterns ["* * * * *", "*/1 * * * *"]
  @default_max_jobs 50

  alias Jido.AgentServer.Signal.CronTick

  @impl true
  def run(params, context) do
    %{schedule: schedule, task: task} = params
    mode = Map.get(params, :mode) || "isolated"
    model = Map.get(params, :model)
    agent_id = context[:agent_id]

    with {:ok, channel, external_id} <- resolve_channel(params, context),
         :ok <- validate_mode(mode),
         :ok <- validate_model(model),
         :ok <- validate_cron(schedule),
         :ok <- check_job_limit() do
      warn_high_frequency(schedule)

      message = build_message(task, channel, external_id, mode, model)

      hash =
        :crypto.hash(
          :sha256,
          "#{schedule}:#{task}:#{channel}:#{external_id}:#{mode}:#{model || "default"}"
        )
        |> Base.encode16(case: :lower)
        |> binary_part(0, 16)

      job_id = :"cron_#{hash}"

      signal = build_cron_tick_signal(message, job_id, agent_id)

      register_and_persist(agent_id, signal, %{
        schedule: schedule,
        task: task,
        channel: channel,
        external_id: external_id,
        mode: mode,
        model: model,
        job_id: job_id
      })
    end
  end

  # Explicit channel/external_id params take priority.
  defp resolve_channel(%{channel: channel} = params, _context)
       when is_binary(channel) and channel != "" do
    case Map.get(params, :external_id) do
      external_id when is_binary(external_id) and external_id != "" ->
        {:ok, channel, external_id}

      _ ->
        {:error, "external_id is required when channel is provided"}
    end
  end

  defp resolve_channel(%{external_id: external_id}, _context)
       when is_binary(external_id) and external_id != "" do
    {:error, "channel is required when external_id is provided"}
  end

  defp resolve_channel(_params, context) do
    case channel_from_agent_id(context[:agent_id]) do
      {:ok, _, _} = ok -> ok
      :error -> channel_from_config()
    end
  end

  defp channel_from_agent_id("telegram:" <> chat_id), do: {:ok, "telegram", chat_id}
  defp channel_from_agent_id("cli:direct:" <> _), do: {:ok, "cli", "direct"}
  defp channel_from_agent_id(_), do: :error

  defp channel_from_config do
    channel = Goodwizard.Config.get(["scheduling", "channel"])
    external_id = Goodwizard.Config.get(["scheduling", "chat_id"])

    case {channel, external_id} do
      {ch, id} when is_binary(ch) and ch != "" and is_binary(id) and id != "" ->
        {:ok, ch, id}

      _ ->
        {:error,
         "Cannot resolve delivery target: agent context not recognized and no [scheduling] config found. " <>
           "Set channel and chat_id under [scheduling] in config.toml, or provide channel/external_id params."}
    end
  end

  defp validate_model(nil), do: :ok

  defp validate_model(model) when is_binary(model) do
    if Enum.any?(@known_model_prefixes, &String.starts_with?(model, &1)) do
      :ok
    else
      {:error,
       "Invalid model #{inspect(model)} — must start with a known provider prefix: #{Enum.join(@known_model_prefixes, ", ")}"}
    end
  end

  defp validate_mode(mode) when mode in @valid_modes, do: :ok

  defp validate_mode(mode),
    do: {:error, "Invalid mode #{inspect(mode)} — must be \"main\" or \"isolated\""}

  defp build_message(task, channel, external_id, mode, model) do
    base = %{
      type: "cron.task",
      task: task,
      channel: channel,
      external_id: external_id,
      mode: mode
    }

    if mode == "isolated" && model do
      Map.put(base, :model, model)
    else
      base
    end
  end

  defp warn_high_frequency(schedule) do
    if schedule in @high_frequency_patterns do
      Logger.warning(
        "Cron schedule #{inspect(schedule)} runs every minute — consider a less frequent interval"
      )
    end
  end

  defp check_job_limit do
    max_jobs = Goodwizard.Config.get(["cron", "max_jobs"]) || @default_max_jobs

    case CronStore.list() do
      {:ok, jobs} when length(jobs) >= max_jobs ->
        {:error,
         "Cron job limit reached (#{max_jobs}). Cancel existing jobs before scheduling new ones."}

      _ ->
        :ok
    end
  end

  alias Crontab.CronExpression

  defp validate_cron(expr) do
    case CronExpression.Parser.parse(expr) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, "Invalid cron expression: #{expr} — #{inspect(reason)}"}
    end
  end

  defp register_and_persist(agent_id, signal, job) do
    tick_fn = fn ->
      dispatch_tick(agent_id, signal)
      :ok
    end

    case Jido.Scheduler.run_every(tick_fn, job.schedule, []) do
      {:ok, sched_pid} ->
        # SchedEx.Runner uses GenServer.start_link, which links the runner
        # to the calling process. When called from the jido_ai executor
        # (which wraps tool calls in Task.async), the SchedEx process would
        # die when the short-lived Task exits. Unlinking lets the SchedEx
        # runner outlive the caller. CronRegistry monitors it independently.
        Process.unlink(sched_pid)
        CronRegistry.register(job.job_id, sched_pid)

        CronStore.save(%{
          job_id: job.job_id,
          schedule: job.schedule,
          task: job.task,
          channel: job.channel,
          external_id: job.external_id,
          mode: job.mode,
          model: job.model,
          created_at: DateTime.utc_now() |> DateTime.to_iso8601()
        })

        {:ok,
         %{
           scheduled: true,
           schedule: job.schedule,
           task: job.task,
           channel: job.channel,
           external_id: job.external_id,
           mode: job.mode,
           job_id: job.job_id
         }}

      {:error, reason} ->
        {:error, "Failed to register cron job: #{inspect(reason)}"}
    end
  end

  defp dispatch_tick(agent_id, signal) do
    case Goodwizard.Jido.whereis(agent_id) do
      pid when is_pid(pid) -> Jido.AgentServer.cast(pid, signal)
      nil -> Logger.warning("Cron tick: agent #{agent_id} not found, skipping")
    end
  end

  defp build_cron_tick_signal(message, job_id, agent_id) do
    CronTick.new!(
      %{job_id: job_id, message: message},
      source: "/agent/#{agent_id}"
    )
  end
end
