defmodule Goodwizard.Actions.Scheduling.Cron do
  @moduledoc """
  Schedules a recurring task on a cron expression.

  Validates the cron expression and emits a `Directive.Cron` for Jido's
  scheduler to pick up. The action stays stateless — it transforms input
  into a scheduling instruction.

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
      room_id: [type: :string, required: true, doc: "Target Messaging room identifier"],
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

  alias Jido.Agent.Directive

  @valid_modes ~w(main isolated)

  # Standard 5-field cron has a minimum resolution of 1 minute.
  # Warn on every-minute schedules to flag potential resource abuse.
  @high_frequency_patterns ["* * * * *", "*/1 * * * *"]

  @impl true
  def run(params, _context) do
    %{schedule: schedule, task: task, room_id: room_id} = params
    mode = Map.get(params, :mode) || "isolated"
    model = Map.get(params, :model)

    with :ok <- validate_mode(mode),
         :ok <- validate_cron(schedule) do
      warn_high_frequency(schedule)

      message = build_message(task, room_id, mode, model)
      job_id = :"cron_#{:erlang.phash2({schedule, task, room_id, mode})}"
      directive = Directive.cron(schedule, message, job_id: job_id)

      {:ok,
       %{
         scheduled: true,
         schedule: schedule,
         task: task,
         room_id: room_id,
         mode: mode,
         job_id: job_id
       }, [directive]}
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

  alias Crontab.CronExpression

  defp validate_cron(expr) do
    case CronExpression.Parser.parse(expr) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, "Invalid cron expression: #{expr} — #{inspect(reason)}"}
    end
  end
end
