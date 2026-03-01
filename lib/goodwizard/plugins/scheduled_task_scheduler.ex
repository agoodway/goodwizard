defmodule Goodwizard.Plugins.ScheduledTaskScheduler do
  @moduledoc """
  Plugin that handles `jido.scheduled_task_tick` signals for the agent.

  Routes scheduled task ticks based on the `mode` field in the message payload:

  - `"main"` — transforms the signal into a `react.input` so the task
    is processed inline through the main agent's ReAct pipeline.
  - `"isolated"` (default) — spawns a child SubAgent via `ScheduledTaskRunner`,
    runs the task in isolation, and saves the result to the target room.

  ## Room Resolution

  Jobs are addressed to a channel + external_id (e.g. `telegram` / `7041440974`).
  The Messaging room is resolved at tick time via `get_or_create_room_by_external_binding`,
  which survives app restarts that wipe the in-memory ETS room store.
  """

  use Jido.Plugin,
    name: "scheduled_task_scheduler",
    description: "Routes scheduled task tick signals to main or isolated execution",
    state_key: :scheduled_task_scheduler,
    actions: [],
    signal_patterns: ["jido.scheduled_task_tick"]

  require Logger

  alias Goodwizard.Actions.Scheduling.ScheduledTaskRunner
  alias Goodwizard.Messaging

  # Instance IDs must match what each channel handler uses when creating rooms.
  @telegram_instance_id to_string(Goodwizard.Channels.Telegram.Handler)
  @cli_instance_id "goodwizard"

  @impl Jido.Plugin
  def mount(_agent, _config) do
    {:ok, %{}}
  end

  @impl Jido.Plugin
  def handle_signal(%{type: "jido.scheduled_task_tick"} = signal, context) do
    message = (signal.data[:message] || %{}) |> normalize_keys()
    task = message[:task]
    channel = message[:channel]
    external_id = message[:external_id]
    mode = message[:mode] || "isolated"
    model = message[:model]

    Logger.info(
      "Scheduled task tick received: mode=#{mode}, task=#{inspect(task)}, " <>
        "channel=#{inspect(channel)}, external_id=#{inspect(external_id)}"
    )

    case resolve_room(channel, external_id) do
      {:ok, room_id} ->
        case mode do
          "main" -> dispatch_main(task, room_id, context)
          _ -> dispatch_isolated(task, room_id, model)
        end

      {:error, reason} ->
        Logger.error("Scheduled task tick: failed to resolve room: #{inspect(reason)}")
        {:ok, {:override, Jido.Actions.Control.Noop}}
    end
  end

  def handle_signal(_signal, _context) do
    {:ok, :continue}
  end

  # Resolve the Messaging room from channel + external_id. Creates the room
  # with proper external_bindings if it doesn't exist (e.g. after restart).
  defp resolve_room(channel, external_id)
       when is_binary(channel) and is_binary(external_id) do
    with {:ok, instance_id, channel_atom} <- channel_info(channel) do
      case Messaging.get_or_create_room_by_external_binding(
             channel_atom,
             instance_id,
             external_id,
             %{type: :direct, name: "Scheduled Task Target"}
           ) do
        {:ok, room} -> {:ok, room.id}
        {:error, _} = err -> err
      end
    end
  end

  # Legacy fallback: room_id passed directly (old-format jobs).
  defp resolve_room(nil, nil), do: {:error, "no channel/external_id in scheduled task message"}

  defp resolve_room(_, _), do: {:error, "invalid channel/external_id in scheduled task message"}

  defp channel_info("telegram"), do: {:ok, @telegram_instance_id, :telegram}
  defp channel_info("cli"), do: {:ok, @cli_instance_id, :cli}
  defp channel_info(other), do: {:error, "unsupported channel: #{inspect(other)}"}

  # Main mode: override the signal to route through react.input so the
  # main agent processes the task inline in its own pipeline.
  defp dispatch_main(task, room_id, _context) do
    save_scheduled_task_message(room_id, task)

    query = "[Scheduled Task] #{task}"

    new_signal =
      Jido.Signal.new!("ai.react.query", %{query: query}, source: "/scheduled_task/main")

    {:ok, {:override, {:strategy_cmd, :ai_react_start}, new_signal}}
  end

  # Isolated mode: spawn a child agent in a background task. Overrides
  # the signal with a Noop action to prevent "No route for signal" errors.
  defp dispatch_isolated(task, room_id, model) do
    opts = if model, do: [model: model], else: []

    Task.Supervisor.start_child(Goodwizard.Jido.task_supervisor_name(), fn ->
      case ScheduledTaskRunner.run_isolated(task, room_id, opts) do
        {:ok, _response} ->
          Logger.info("Isolated scheduled task completed: task=#{inspect(task)}")

        {:error, reason} ->
          Logger.error(
            "Isolated scheduled task failed: task=#{inspect(task)}, reason=#{inspect(reason)}"
          )
      end
    end)

    {:ok, {:override, Jido.Actions.Control.Noop}}
  end

  defp save_scheduled_task_message(room_id, task) do
    Messaging.save_message(%{
      room_id: room_id,
      sender_id: "scheduled_task:main",
      role: :user,
      content: [%{type: "text", text: "[Scheduled Task] #{task}"}]
    })
  end

  @known_keys %{
    "task" => :task,
    "channel" => :channel,
    "external_id" => :external_id,
    "mode" => :mode,
    "model" => :model,
    "type" => :type
  }

  defp normalize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {Map.get(@known_keys, k, k), v}
      {k, v} -> {k, v}
    end)
  end
end
