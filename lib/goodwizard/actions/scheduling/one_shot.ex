defmodule Goodwizard.Actions.Scheduling.OneShot do
  @moduledoc """
  Schedules a one-shot task by delay or wall-clock time.

  Accepts either `delay_minutes` (relative) or `at` (absolute ISO 8601 UTC),
  but not both. Uses `:timer.apply_after` to dispatch a CronTick-compatible
  signal so the existing signal pipeline processes it identically to recurring
  cron tasks.

  Jobs are persisted to disk via `OneShotStore` and their timer references
  are tracked in `OneShotRegistry`. After firing, the persisted file is
  deleted and the registry entry is removed. Use `CancelOneShot` to cancel
  a pending job, or `ListOneShotJobs` to view all scheduled jobs.
  """

  require Logger

  @max_delay_minutes 525_600

  use Jido.Action,
    name: "schedule_oneshot_task",
    description:
      "Schedule a single-fire task. Provide either delay_minutes (positive integer, " <>
        "minutes from now) OR at (ISO 8601 UTC datetime, e.g. \"2026-02-15T15:00:00Z\"). " <>
        "Exactly one must be given. The task fires once and is not recurring. " <>
        "The job is persisted to disk and survives application restarts.",
    schema: [
      delay_minutes: [type: :integer, required: false, doc: "Minutes from now to fire (positive integer)"],
      at: [type: :string, required: false, doc: "ISO 8601 UTC datetime to fire at (e.g. \"2026-02-15T15:00:00Z\")"],
      task: [type: :string, required: true, doc: "Description of the task to execute"],
      room_id: [type: :string, required: false, doc: "Target Messaging room identifier. Auto-resolved from agent context when omitted."]
    ]

  alias Goodwizard.Actions.Brain.Helpers
  alias Goodwizard.Scheduling.{OneShotStore, OneShotRegistry}

  @impl true
  def run(params, context) do
    task = params.task
    delay_minutes = Map.get(params, :delay_minutes)
    at = Map.get(params, :at)
    agent_id = context[:agent_id]

    Logger.debug("[OneShot] params=#{inspect(params)} agent_id=#{inspect(agent_id)}")

    with {:ok, room_id} <- resolve_room(params, context),
         :ok <- validate_exclusivity(delay_minutes, at),
         {:ok, delay_ms, fires_at, mode} <- compute_delay(delay_minutes, at) do
      message = %{type: "cron.task", task: task, room_id: room_id}
      job_id = generate_job_id(fires_at, task, room_id)

      signal = build_cron_tick_signal(message, job_id, agent_id)

      {:ok, tref} = :timer.apply_after(delay_ms, __MODULE__, :deliver, [agent_id, signal, job_id])

      # Persist to disk for restart recovery
      OneShotStore.save(%{
        job_id: job_id,
        task: task,
        room_id: room_id,
        fires_at: fires_at,
        created_at: DateTime.utc_now()
      })

      # Track timer reference for cancellation
      OneShotRegistry.register(job_id, tref)

      {:ok,
       %{
         scheduled: true,
         task: task,
         room_id: room_id,
         job_id: job_id,
         fires_at: fires_at,
         mode: mode
       }}
    end
  end

  @doc false
  def deliver(agent_id, signal, job_id) do
    # Clean up persisted file and registry entry after firing
    OneShotStore.delete(job_id)
    OneShotRegistry.deregister(job_id)

    case Goodwizard.Jido.whereis(agent_id) do
      pid when is_pid(pid) -> Jido.AgentServer.cast(pid, signal)
      nil -> Logger.warning("OneShot: agent #{agent_id} not found, signal dropped")
    end
  end

  # Legacy 2-arity deliver for any in-flight timers scheduled before
  # the persistence upgrade. Safe to remove after one release cycle.
  @doc false
  def deliver(agent_id, signal) do
    case Goodwizard.Jido.whereis(agent_id) do
      pid when is_pid(pid) -> Jido.AgentServer.cast(pid, signal)
      nil -> Logger.warning("OneShot: agent #{agent_id} not found, signal dropped")
    end
  end

  @doc """
  Generate a deterministic job ID from the job's defining attributes.

  Uses SHA256 of `{fires_at, task, room_id}`, takes first 16 hex chars,
  and prefixes with `oneshot_`.
  """
  def generate_job_id(fires_at, task, room_id) do
    input = :erlang.term_to_binary({DateTime.to_iso8601(fires_at), task, room_id})
    hash = :crypto.hash(:sha256, input) |> Base.encode16(case: :lower) |> binary_part(0, 16)
    :"oneshot_#{hash}"
  end

  defp validate_exclusivity(nil, nil),
    do: {:error, "Exactly one of delay_minutes or at must be provided"}

  defp validate_exclusivity(_delay, nil), do: :ok
  defp validate_exclusivity(nil, _at), do: :ok

  defp validate_exclusivity(_, _),
    do: {:error, "Exactly one of delay_minutes or at must be provided — got both"}

  defp resolve_room(%{room_id: room_id}, _context) when is_binary(room_id) and room_id != "",
    do: {:ok, room_id}

  defp resolve_room(_params, context), do: Helpers.resolve_room_id(context)

  defp compute_delay(delay_minutes, nil) when is_integer(delay_minutes) do
    cond do
      delay_minutes <= 0 ->
        {:error, "delay_minutes must be a positive integer, got: #{inspect(delay_minutes)}"}

      delay_minutes > @max_delay_minutes ->
        {:error, "delay_minutes exceeds maximum of #{@max_delay_minutes} (1 year), got: #{inspect(delay_minutes)}"}

      true ->
        delay_ms = delay_minutes * 60_000
        fires_at = DateTime.add(DateTime.utc_now(), delay_minutes, :minute)
        {:ok, delay_ms, fires_at, "delay"}
    end
  end

  defp compute_delay(nil, at_string) when is_binary(at_string) do
    case DateTime.from_iso8601(at_string) do
      {:ok, _at_dt, offset} when offset != 0 ->
        {:error, "Only UTC datetimes are supported (use Z suffix), got offset: #{inspect(at_string)}"}

      {:ok, at_dt, _offset} ->
        now = DateTime.utc_now()
        delay_ms = DateTime.diff(at_dt, now, :millisecond)

        if delay_ms > 0 do
          {:ok, delay_ms, at_dt, "at"}
        else
          {:error, "Scheduled time is in the past: #{inspect(at_string)}"}
        end

      {:error, _reason} ->
        {:error, "Invalid ISO 8601 datetime: #{inspect(at_string)}"}
    end
  end

  defp build_cron_tick_signal(message, job_id, agent_id) do
    Jido.AgentServer.Signal.CronTick.new!(
      %{job_id: job_id, message: message},
      source: "/agent/#{agent_id}"
    )
  end
end
