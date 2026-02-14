defmodule Goodwizard.Actions.Scheduling.Cron do
  @moduledoc """
  Schedules a recurring task on a cron expression.

  Validates the cron expression and emits a `Directive.Cron` for Jido's
  scheduler to pick up. The action stays stateless — it transforms input
  into a scheduling instruction.
  """

  use Jido.Action,
    name: "schedule_cron_task",
    description:
      "Schedule a recurring task using a cron expression. " <>
        "Supports standard 5-field cron (minute hour day month weekday), " <>
        "aliases (@daily, @hourly, @weekly, @monthly, @yearly), " <>
        "and extended expressions. Examples: \"0 9 * * *\" (daily at 9am), " <>
        "\"*/5 * * * *\" (every 5 minutes), \"0 9 * * MON\" (Mondays at 9am).",
    schema: [
      schedule: [type: :string, required: true, doc: "Cron expression (e.g. \"0 9 * * *\")"],
      task: [type: :string, required: true, doc: "Description of the task to execute"],
      room_id: [type: :string, required: true, doc: "Target Messaging room identifier"]
    ]

  alias Jido.Agent.Directive

  @impl true
  def run(%{schedule: schedule, task: task, room_id: room_id}, _context) do
    case validate_cron(schedule) do
      :ok ->
        message = %{type: "cron.task", task: task, room_id: room_id}
        job_id = :"cron_#{:erlang.phash2({schedule, task, room_id})}"
        directive = Directive.cron(schedule, message, job_id: job_id)

        {:ok,
         %{
           scheduled: true,
           schedule: schedule,
           task: task,
           room_id: room_id,
           job_id: job_id
         }, [directive]}

      {:error, reason} ->
        {:error, "Invalid cron expression: #{schedule} — #{reason}"}
    end
  end

  defp validate_cron(expr) do
    case Crontab.CronExpression.Parser.parse(expr) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, inspect(reason)}
    end
  end
end
