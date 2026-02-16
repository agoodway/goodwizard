defmodule Goodwizard.Actions.Scheduling.Cron do
  @moduledoc """
  Schedules a recurring task on a cron expression.

  Validates the cron expression and registers the job directly with
  `Jido.Scheduler.run_every`, bypassing the executor's directive pipeline.
  The scheduler pid is tracked in `CronRegistry` for later cancellation.

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
      room_id: [
        type: :string,
        required: false,
        doc: "Target Messaging room identifier. Auto-resolved from agent context when omitted."
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

  alias Goodwizard.Scheduling.{CronStore, CronRegistry}

  @valid_modes ~w(main isolated)
  @known_model_prefixes ~w(anthropic: openai: google: ollama: mistral:)

  # Standard 5-field cron has a minimum resolution of 1 minute.
  # Warn on every-minute schedules to flag potential resource abuse.
  @high_frequency_patterns ["* * * * *", "*/1 * * * *"]
  @default_max_jobs 50

  alias Goodwizard.Actions.Brain.Helpers

  @impl true
  def run(params, context) do
    %{schedule: schedule, task: task} = params
    mode = Map.get(params, :mode) || "isolated"
    model = Map.get(params, :model)
    agent_id = context[:agent_id]

    with {:ok, room_id} <- resolve_room(params, context),
         :ok <- validate_mode(mode),
         :ok <- validate_model(model),
         :ok <- validate_cron(schedule),
         :ok <- check_job_limit() do
      warn_high_frequency(schedule)

      message = build_message(task, room_id, mode, model)

      hash =
        :crypto.hash(:sha256, "#{schedule}:#{task}:#{room_id}:#{mode}:#{model || "default"}")
        |> Base.encode16(case: :lower)
        |> binary_part(0, 16)

      job_id = :"cron_#{hash}"

      signal = build_cron_tick_signal(message, job_id, agent_id)

      case Jido.Scheduler.run_every(
             fn ->
               case Goodwizard.Jido.whereis(agent_id) do
                 pid when is_pid(pid) -> Jido.AgentServer.cast(pid, signal)
                 nil -> Logger.warning("Cron tick: agent #{agent_id} not found, skipping")
               end

               :ok
             end,
             schedule,
             []
           ) do
        {:ok, sched_pid} ->
          CronRegistry.register(job_id, sched_pid)

          CronStore.save(%{
            job_id: job_id,
            schedule: schedule,
            task: task,
            room_id: room_id,
            mode: mode,
            model: model,
            created_at: DateTime.utc_now() |> DateTime.to_iso8601()
          })

          {:ok,
           %{
             scheduled: true,
             schedule: schedule,
             task: task,
             room_id: room_id,
             mode: mode,
             job_id: job_id
           }}

        {:error, reason} ->
          {:error, "Failed to register cron job: #{inspect(reason)}"}
      end
    end
  end

  defp resolve_room(%{room_id: room_id}, _context) when is_binary(room_id) and room_id != "",
    do: {:ok, room_id}

  defp resolve_room(_params, context), do: Helpers.resolve_room_id(context)

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

  defp build_message(task, room_id, mode, model) do
    base = %{type: "cron.task", task: task, room_id: room_id, mode: mode}

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
        {:error, "Cron job limit reached (#{max_jobs}). Cancel existing jobs before scheduling new ones."}

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

  defp build_cron_tick_signal(message, job_id, agent_id) do
    Jido.AgentServer.Signal.CronTick.new!(
      %{job_id: job_id, message: message},
      source: "/agent/#{agent_id}"
    )
  end
end
