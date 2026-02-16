defmodule Goodwizard.Plugins.CronScheduler do
  @moduledoc """
  Plugin that handles `jido.cron_tick` signals for the agent.

  Routes cron ticks based on the `mode` field in the message payload:

  - `"main"` — transforms the signal into a `react.input` so the task
    is processed inline through the main agent's ReAct pipeline.
  - `"isolated"` (default) — spawns a child SubAgent via `CronRunner`,
    runs the task in isolation, and saves the result to the target room.
  """

  use Jido.Plugin,
    name: "cron_scheduler",
    description: "Routes cron tick signals to main or isolated execution",
    state_key: :cron_scheduler,
    actions: [],
    signal_patterns: ["jido.cron_tick"]

  require Logger

  alias Goodwizard.Actions.Scheduling.CronRunner
  alias Goodwizard.Messaging

  @impl Jido.Plugin
  def mount(_agent, _config) do
    {:ok, %{}}
  end

  @impl Jido.Plugin
  def handle_signal(%{type: "jido.cron_tick"} = signal, context) do
    message = signal.data[:message] || %{}
    task = message[:task] || message["task"]
    room_id = message[:room_id] || message["room_id"]
    mode = message[:mode] || message["mode"] || "isolated"
    model = message[:model] || message["model"]

    Logger.info(
      "Cron tick received: mode=#{mode}, task=#{inspect(task)}, room_id=#{inspect(room_id)}"
    )

    case mode do
      "main" ->
        dispatch_main(task, room_id, context)

      _ ->
        dispatch_isolated(task, room_id, model)
    end
  end

  def handle_signal(_signal, _context) do
    {:ok, :continue}
  end

  # Main mode: override the signal to route through react.input so the
  # main agent processes the task inline in its own pipeline.
  defp dispatch_main(task, room_id, _context) do
    save_cron_task_message(room_id, task)

    query = "[Cron Task] #{task}"

    new_signal =
      Jido.Signal.new!("react.input", %{query: query}, source: "/cron/main")

    {:ok, {:override, {:strategy_cmd, :react_start}, new_signal}}
  end

  # Isolated mode: spawn a child agent in a background task. Returns
  # :continue so the main agent is not blocked.
  defp dispatch_isolated(task, room_id, model) do
    opts = if model, do: [model: model], else: []

    Task.start(fn ->
      case CronRunner.run_isolated(task, room_id, opts) do
        {:ok, _response} ->
          Logger.info("Isolated cron completed: task=#{inspect(task)}")

        {:error, reason} ->
          Logger.error("Isolated cron failed: task=#{inspect(task)}, reason=#{inspect(reason)}")
      end
    end)

    {:ok, :continue}
  end

  defp save_cron_task_message(room_id, task) do
    Messaging.save_message(%{
      room_id: room_id,
      sender_id: "cron:main",
      role: :user,
      content: [%{type: "text", text: "[Cron Task] #{task}"}]
    })
  end
end
