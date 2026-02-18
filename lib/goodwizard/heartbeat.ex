defmodule Goodwizard.Heartbeat do
  @moduledoc """
  Periodic heartbeat that reads HEARTBEAT.md from the workspace and
  processes its contents as a message through the agent pipeline.

  Uses `Process.send_after/3` for periodic ticks. Targets a configurable
  Messaging room. Skips processing when the file is missing or unchanged
  since the last read.
  """
  use GenServer

  require Logger

  alias Goodwizard.Agent, as: GoodwizardAgent
  alias Goodwizard.Heartbeat.Parser
  alias Goodwizard.Messaging

  @default_interval_ms :timer.minutes(5)
  @default_timeout_ms 120_000

  @doc "Starts the heartbeat GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval_ms, resolve_interval())
    workspace = Keyword.get(opts, :workspace) || Goodwizard.Config.workspace()
    heartbeat_path = Path.join(workspace, "HEARTBEAT.md")

    # Resolve room binding from config
    {channel, instance_id, external_id} = resolve_room_binding()

    room_result =
      Messaging.get_or_create_room_by_external_binding(channel, instance_id, external_id, %{
        type: :direct,
        name: "Heartbeat"
      })

    case room_result do
      {:ok, room} ->
        start_agent_and_schedule(room, interval, workspace, heartbeat_path)

      {:error, reason} ->
        Logger.error("Heartbeat failed to create room: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  defp start_agent_and_schedule(room, interval, workspace, heartbeat_path) do
    agent_id = "heartbeat:#{System.unique_integer([:positive])}"

    case Goodwizard.Jido.start_agent(GoodwizardAgent,
           id: agent_id,
           initial_state: %{workspace: workspace, channel: "heartbeat", chat_id: "heartbeat"}
         ) do
      {:ok, agent_pid} ->
        state = %{
          interval: interval,
          heartbeat_path: heartbeat_path,
          room_id: room.id,
          agent_pid: agent_pid,
          last_mtime: nil
        }

        schedule_tick(interval)
        Logger.info("Heartbeat started, interval=#{interval}ms, file=#{heartbeat_path}")
        {:ok, state}

      {:error, reason} ->
        Logger.error("Heartbeat failed to start agent: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:tick, state) do
    state = process_heartbeat(state)
    schedule_tick(state.interval)
    {:noreply, state}
  end

  defp process_heartbeat(state) do
    case File.stat(state.heartbeat_path) do
      {:ok, %{mtime: mtime}} when mtime == state.last_mtime ->
        Logger.debug("Heartbeat: HEARTBEAT.md unchanged, skipping")
        state

      {:ok, %{mtime: mtime}} ->
        process_changed_file(state, mtime)

      {:error, :enoent} ->
        Logger.debug("Heartbeat: HEARTBEAT.md not found, skipping")
        state

      {:error, reason} ->
        Logger.warning("Heartbeat: failed to stat HEARTBEAT.md: #{inspect(reason)}")
        state
    end
  end

  defp process_changed_file(state, mtime) do
    case File.read(state.heartbeat_path) do
      {:ok, content} ->
        content
        |> String.trim()
        |> dispatch_content(state)

        %{state | last_mtime: mtime}

      {:error, reason} ->
        Logger.warning("Heartbeat: failed to read HEARTBEAT.md: #{inspect(reason)}")
        state
    end
  end

  defp dispatch_content("", _state) do
    Logger.debug("Heartbeat: HEARTBEAT.md is empty, skipping")
  end

  defp dispatch_content(content, state) do
    case Parser.parse(content) do
      {:structured, checks} ->
        prompt = Parser.build_prompt(checks)
        dispatch_heartbeat(prompt, state, checks: checks)

      {:plain, plain_content} ->
        dispatch_heartbeat(plain_content, state)
    end
  end

  defp dispatch_heartbeat(content, state, opts \\ []) do
    Logger.info("Heartbeat: processing HEARTBEAT.md")

    user_message = %{
      room_id: state.room_id,
      sender_id: "heartbeat",
      role: :user,
      content: [%{type: "text", text: content}]
    }

    user_message =
      case Keyword.get(opts, :checks) do
        nil -> user_message
        checks -> Map.put(user_message, :metadata, %{checks: checks})
      end

    Messaging.save_message(user_message)

    case GoodwizardAgent.ask_sync(state.agent_pid, content, timeout: resolve_timeout()) do
      {:ok, response} ->
        Messaging.save_message(%{
          room_id: state.room_id,
          sender_id: "assistant",
          role: :assistant,
          content: [%{type: "text", text: response}]
        })

        Logger.info("Heartbeat: completed, response byte_size=#{byte_size(response)}")

      {:error, reason} ->
        Logger.error("Heartbeat: agent error: #{inspect(reason)}")
    end
  end

  defp schedule_tick(interval) do
    Process.send_after(self(), :tick, interval)
  end

  @doc false
  def resolve_interval do
    case Goodwizard.Config.get(["heartbeat", "interval_minutes"]) do
      nil -> @default_interval_ms
      minutes when is_number(minutes) -> trunc(minutes * 60_000)
      _ -> @default_interval_ms
    end
  end

  @doc false
  def resolve_timeout do
    case Goodwizard.Config.get(["heartbeat", "timeout_seconds"]) do
      nil -> @default_timeout_ms
      seconds when is_number(seconds) -> trunc(seconds * 1_000)
      _ -> @default_timeout_ms
    end
  end

  @known_channels ~w(cli telegram)a

  @doc false
  def resolve_room_binding do
    channel = Goodwizard.Config.get(["heartbeat", "channel"])
    chat_id = Goodwizard.Config.get(["heartbeat", "chat_id"])

    case {channel, chat_id} do
      {ch, id} when is_binary(ch) and is_binary(id) ->
        channel_atom =
          case String.to_existing_atom(ch) do
            atom when atom in @known_channels ->
              atom

            _ ->
              Logger.warning("Unknown heartbeat channel #{inspect(ch)}, falling back to :cli")
              :cli
          end

        {channel_atom, "goodwizard", id}

      _ ->
        {:cli, "goodwizard", "heartbeat"}
    end
  rescue
    ArgumentError ->
      Logger.warning("Unknown heartbeat channel atom, falling back to :cli")
      {:cli, "goodwizard", "heartbeat"}
  end
end
