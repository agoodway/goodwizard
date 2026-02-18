defmodule Goodwizard.Actions.Scheduling.OneTime do
  @moduledoc """
  Schedules a one-time task by delay or wall-clock time.

  Accepts either `delay_minutes` (relative) or `at` (absolute ISO 8601 UTC),
  but not both. Uses `:timer.apply_after` to dispatch a scheduled-task tick
  signal so the existing signal pipeline processes it identically to recurring
  scheduled tasks.

  Jobs are persisted to disk via `OneTimeStore` and their timer references
  are tracked in `OneTimeRegistry`. After firing, the persisted file is
  deleted and the registry entry is removed. Use `CancelOneTime` to cancel
  a pending job, or `ListOneTimeJobs` to view all scheduled jobs.

  ## Delivery Targeting

  Jobs are addressed to a **channel** and **external_id** rather than a
  Messaging room UUID. The room is resolved at delivery time by the
  ScheduledTaskScheduler plugin, which survives app restarts.
  """

  require Logger

  @max_delay_minutes 525_600
  @max_task_length 2000
  @max_external_id_length 256
  @max_pending_jobs 500

  use Jido.Action,
    name: "schedule_one_time_task",
    description:
      "Schedule a single-fire task. Provide either delay_minutes (positive integer, " <>
        "minutes from now) OR at (ISO 8601 UTC datetime, e.g. \"2026-02-15T15:00:00Z\"). " <>
        "Exactly one must be given. The task fires once and is not recurring. " <>
        "The job is persisted to disk and survives application restarts.",
    schema: [
      delay_minutes: [
        type: :integer,
        required: false,
        doc: "Minutes from now to fire (positive integer)"
      ],
      at: [
        type: :string,
        required: false,
        doc: "ISO 8601 UTC datetime to fire at (e.g. \"2026-02-15T15:00:00Z\")"
      ],
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
      ]
    ]

  alias Goodwizard.Scheduling.{OneTimeRegistry, OneTimeStore}

  @impl true
  def run(params, context) do
    task = params.task
    delay_minutes = Map.get(params, :delay_minutes)
    at = Map.get(params, :at)
    agent_id = context[:agent_id]

    Logger.debug("[OneTime] params=#{inspect(params)} agent_id=#{inspect(agent_id)}")

    with :ok <- validate_length(task, "task", @max_task_length),
         {:ok, channel, external_id} <- resolve_channel(params, context),
         :ok <- validate_length(external_id, "external_id", @max_external_id_length),
         :ok <- validate_exclusivity(delay_minutes, at),
         :ok <- check_pending_job_cap(),
         {:ok, delay_ms, fires_at, mode} <- compute_delay(delay_minutes, at) do
      message = %{
        type: "scheduled_task.task",
        task: task,
        channel: channel,
        external_id: external_id
      }

      job_id = generate_job_id(fires_at, task, channel, external_id)

      signal = build_scheduled_task_tick_signal(message, job_id, agent_id)

      {:ok, tref} = :timer.apply_after(delay_ms, __MODULE__, :deliver, [agent_id, signal, job_id])

      # Persist to disk for restart recovery; cancel timer on failure
      case OneTimeStore.save(%{
             job_id: job_id,
             task: task,
             channel: channel,
             external_id: external_id,
             agent_id: agent_id,
             fires_at: fires_at,
             created_at: DateTime.utc_now()
           }) do
        :ok ->
          # Track timer reference for cancellation
          OneTimeRegistry.register(job_id, tref)

          {:ok,
           %{
             scheduled: true,
             task: task,
             channel: channel,
             external_id: external_id,
             job_id: job_id,
             fires_at: fires_at,
             mode: mode
           }}

        {:error, reason} ->
          :timer.cancel(tref)
          {:error, "Failed to persist one-time task: #{inspect(reason)}"}
      end
    end
  end

  @doc false
  def deliver(agent_id, signal, job_id) do
    # Clean up persisted file and registry entry after firing
    OneTimeStore.delete(job_id)
    OneTimeRegistry.deregister(job_id)

    case Goodwizard.Jido.whereis(agent_id) do
      pid when is_pid(pid) -> Jido.AgentServer.cast(pid, signal)
      nil -> Logger.warning("OneTime: agent #{agent_id} not found, signal dropped")
    end
  end

  # Legacy 2-arity deliver for any in-flight timers scheduled before
  # the persistence upgrade. Safe to remove after one release cycle.
  @doc false
  def deliver(agent_id, signal) do
    case Goodwizard.Jido.whereis(agent_id) do
      pid when is_pid(pid) -> Jido.AgentServer.cast(pid, signal)
      nil -> Logger.warning("OneTime: agent #{agent_id} not found, signal dropped")
    end
  end

  @doc """
  Generate a deterministic job ID from the job's defining attributes.

  Uses SHA256 of `{fires_at, task, channel, external_id}`, takes first 16
  hex chars, and prefixes with `one_time_`.
  """
  @spec generate_job_id(DateTime.t(), String.t(), String.t(), String.t()) :: atom()
  def generate_job_id(fires_at, task, channel, external_id) do
    input = :erlang.term_to_binary({DateTime.to_iso8601(fires_at), task, channel, external_id})
    hash = :crypto.hash(:sha256, input) |> Base.encode16(case: :lower) |> binary_part(0, 16)
    :"one_time_#{hash}"
  end

  defp validate_length(value, field, max) when is_binary(value) and byte_size(value) > max,
    do: {:error, "#{field} exceeds maximum length of #{max} characters"}

  defp validate_length(_value, _field, _max), do: :ok

  defp check_pending_job_cap do
    case OneTimeStore.list() do
      {:ok, jobs} when length(jobs) >= @max_pending_jobs ->
        {:error, "Maximum pending one-time tasks (#{@max_pending_jobs}) reached"}

      {:ok, _jobs} ->
        :ok

      {:error, _reason} ->
        # If we can't check, allow scheduling — the save will fail if disk is truly broken
        :ok
    end
  end

  defp validate_exclusivity(nil, nil),
    do: {:error, "Exactly one of delay_minutes or at must be provided"}

  defp validate_exclusivity(_delay, nil), do: :ok
  defp validate_exclusivity(nil, _at), do: :ok

  defp validate_exclusivity(_, _),
    do: {:error, "Exactly one of delay_minutes or at must be provided — got both"}

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
         "Cannot resolve delivery target: agent context not recognized and no [scheduling] config found."}
    end
  end

  defp compute_delay(delay_minutes, nil) when is_integer(delay_minutes) do
    cond do
      delay_minutes <= 0 ->
        {:error, "delay_minutes must be a positive integer, got: #{inspect(delay_minutes)}"}

      delay_minutes > @max_delay_minutes ->
        {:error,
         "delay_minutes exceeds maximum of #{@max_delay_minutes} (1 year), got: #{inspect(delay_minutes)}"}

      true ->
        delay_ms = delay_minutes * 60_000
        fires_at = DateTime.add(DateTime.utc_now(), delay_minutes, :minute)
        {:ok, delay_ms, fires_at, "delay"}
    end
  end

  defp compute_delay(nil, at_string) when is_binary(at_string) do
    case DateTime.from_iso8601(at_string) do
      {:ok, _at_dt, offset} when offset != 0 ->
        {:error,
         "Only UTC datetimes are supported (use Z suffix), got offset: #{inspect(at_string)}"}

      {:ok, at_dt, _offset} ->
        now = DateTime.utc_now()
        delay_ms = DateTime.diff(at_dt, now, :millisecond)
        max_delay_ms = @max_delay_minutes * 60_000

        cond do
          delay_ms <= 0 ->
            {:error, "Scheduled time is in the past: #{inspect(at_string)}"}

          delay_ms > max_delay_ms ->
            {:error,
             "Scheduled time exceeds maximum of 1 year in the future: #{inspect(at_string)}"}

          true ->
            {:ok, delay_ms, at_dt, "at"}
        end

      {:error, _reason} ->
        {:error, "Invalid ISO 8601 datetime: #{inspect(at_string)}"}
    end
  end

  defp build_scheduled_task_tick_signal(message, job_id, agent_id) do
    Jido.Signal.new!("jido.scheduled_task_tick", %{job_id: job_id, message: message},
      source: "/agent/#{agent_id}"
    )
  end
end
