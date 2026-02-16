defmodule Goodwizard.Actions.Scheduling.OneShot do
  @moduledoc """
  Schedules a one-shot task by delay or wall-clock time.

  Accepts either `delay_minutes` (relative) or `at` (absolute ISO 8601 UTC),
  but not both. Emits a `Directive.Schedule` with a CronTick-compatible
  message payload so the existing signal pipeline processes it identically
  to recurring cron tasks.

  Note: one-shot tasks cannot be cancelled after scheduling. The returned
  `job_id` is informational only — there is no corresponding cancel action.
  """

  require Logger

  @max_delay_minutes 525_600

  use Jido.Action,
    name: "schedule_oneshot_task",
    description:
      "Schedule a single-fire task. Provide either delay_minutes (positive integer, " <>
        "minutes from now) OR at (ISO 8601 UTC datetime, e.g. \"2026-02-15T15:00:00Z\"). " <>
        "Exactly one must be given. The task fires once and is not recurring.",
    schema: [
      delay_minutes: [type: :integer, required: false, doc: "Minutes from now to fire (positive integer)"],
      at: [type: :string, required: false, doc: "ISO 8601 UTC datetime to fire at (e.g. \"2026-02-15T15:00:00Z\")"],
      task: [type: :string, required: true, doc: "Description of the task to execute"],
      room_id: [type: :string, required: false, doc: "Target Messaging room identifier. Auto-resolved from agent context when omitted."]
    ]

  alias Jido.Agent.Directive

  alias Goodwizard.Actions.Brain.Helpers

  @impl true
  def run(params, context) do
    task = params.task
    delay_minutes = Map.get(params, :delay_minutes)
    at = Map.get(params, :at)

    Logger.debug("[OneShot] params=#{inspect(params)} agent_id=#{inspect(context[:agent_id])}")

    with {:ok, room_id} <- resolve_room(params, context),
         :ok <- validate_exclusivity(delay_minutes, at),
         {:ok, delay_ms, fires_at, mode} <- compute_delay(delay_minutes, at) do
      message = %{type: "cron.task", task: task, room_id: room_id}
      hash_input = if delay_minutes, do: {delay_minutes, task, room_id}, else: {at, task, room_id}
      job_id = :"oneshot_#{:erlang.phash2(hash_input)}"
      directive = Directive.schedule(delay_ms, message)

      {:ok,
       %{
         scheduled: true,
         task: task,
         room_id: room_id,
         job_id: job_id,
         fires_at: fires_at,
         mode: mode
       }, [directive]}
    end
  end

  defp validate_exclusivity(nil, nil),
    do: {:error, "Exactly one of delay_minutes or at must be provided"}

  defp validate_exclusivity(_delay, nil), do: :ok
  defp validate_exclusivity(nil, _at), do: :ok

  defp validate_exclusivity(_, _),
    do: {:error, "Exactly one of delay_minutes or at must be provided — got both"}

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

  defp resolve_room(%{room_id: room_id}, _context) when is_binary(room_id) and room_id != "",
    do: {:ok, room_id}

  defp resolve_room(_params, context), do: Helpers.resolve_room_id(context)

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
end
