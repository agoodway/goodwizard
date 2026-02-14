defmodule Goodwizard.Channels.CLI.Server do
  @moduledoc """
  CLI REPL channel server.

  A GenServer that manages a CLI REPL session — creates a Messaging room,
  starts an AgentServer, and runs a blocking IO loop in a linked Task.

  ## Process lifecycle

  The REPL IO loop runs in a Task linked to this GenServer. When the user
  sends EOF (Ctrl-D), the task exits normally, which terminates this server
  via the link. The `mix goodwizard.cli` task monitors this server and exits
  when it goes down. This is the intended shutdown path.
  """
  use GenServer

  require Logger

  alias Goodwizard.Agent, as: GoodwizardAgent
  alias Goodwizard.Messaging

  @ask_timeout 120_000
  @max_input_length 10_000
  @user_sender_id "user"
  @assistant_sender_id "assistant"

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  if Mix.env() == :test do
    @doc false
    def get_state(pid), do: GenServer.call(pid, :get_state)
  end

  @doc false
  def send_input(pid, input), do: GenServer.call(pid, {:input, input}, @ask_timeout + 5_000)

  @impl true
  def init(opts) do
    workspace = Keyword.get(opts, :workspace, Goodwizard.Config.workspace())

    # Create or retrieve the CLI messaging room
    {:ok, room} =
      Messaging.get_or_create_room_by_external_binding(:cli, "goodwizard", "direct", %{
        type: :direct,
        name: "CLI"
      })

    # Start the agent
    case Goodwizard.Jido.start_agent(GoodwizardAgent,
           id: "cli:direct:#{System.unique_integer([:positive])}",
           initial_state: %{workspace: workspace, channel: "cli", chat_id: "direct"}
         ) do
      {:ok, agent_pid} ->
        state = %{
          room_id: room.id,
          agent_pid: agent_pid,
          workspace: workspace
        }

        # Spawn the blocking REPL loop unless suppressed (for tests)
        if Keyword.get(opts, :start_repl, true) do
          Task.start_link(fn -> repl_loop(state) end)
        end

        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to start agent: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  if Mix.env() == :test do
    @impl true
    def handle_call(:get_state, _from, state) do
      {:reply, state, state}
    end
  end

  @impl true
  def handle_call({:input, input}, _from, state) do
    result = handle_input(input, state)
    {:reply, result, state}
  end

  # -- REPL loop (runs in linked Task) ----------------------------------------

  defp repl_loop(state) do
    case IO.gets("you> ") do
      :eof ->
        :ok

      {:error, reason} ->
        Logger.error("IO error: #{inspect(reason)}")

      input when is_binary(input) ->
        input = String.trim(input)

        if input != "" do
          handle_input(input, state)
        end

        repl_loop(state)
    end
  end

  defp handle_input(input, _state) when byte_size(input) > @max_input_length do
    IO.puts("\n[error] Input exceeds maximum length of #{@max_input_length} bytes\n")
    {:error, :input_too_long}
  end

  defp handle_input(input, state) do
    # Save user message to room
    save_message_with_warning(state.room_id, @user_sender_id, :user, input)

    # Dispatch to agent
    case GoodwizardAgent.ask_sync(state.agent_pid, input, timeout: @ask_timeout) do
      {:ok, response} ->
        # Save assistant message to room
        save_message_with_warning(state.room_id, @assistant_sender_id, :assistant, response)

        IO.puts("\ngoodwizard> #{response}\n")
        {:ok, response}

      {:error, reason} ->
        IO.puts("\n[error] #{inspect(reason)}\n")
        {:error, reason}
    end
  end

  defp save_message_with_warning(room_id, sender_id, role, text) do
    case Messaging.save_message(%{
           room_id: room_id,
           sender_id: sender_id,
           role: role,
           content: [%{type: "text", text: text}]
         }) do
      {:ok, message} ->
        {:ok, message}

      {:error, reason} ->
        Logger.warning("Failed to save #{role} message: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
