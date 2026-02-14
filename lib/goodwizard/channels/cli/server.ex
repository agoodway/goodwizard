defmodule Goodwizard.Channels.CLI.Server do
  @moduledoc """
  CLI REPL channel server.

  A GenServer that manages a CLI REPL session — creates a Messaging room,
  starts an AgentServer, and runs a blocking IO loop in a linked Task.
  """
  use GenServer

  require Logger

  alias Goodwizard.Agent, as: GoodwizardAgent
  alias Goodwizard.Messaging

  @ask_timeout 120_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc false
  def get_state(pid), do: GenServer.call(pid, :get_state)

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
    {:ok, agent_pid} =
      Goodwizard.Jido.start_agent(GoodwizardAgent,
        id: "cli:direct:#{System.unique_integer([:positive])}",
        initial_state: %{workspace: workspace, channel: "cli", chat_id: "direct"}
      )

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
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
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

  defp handle_input(input, state) do
    # Save user message to room
    Messaging.save_message(%{
      room_id: state.room_id,
      sender_id: "user",
      role: :user,
      content: [%{type: "text", text: input}]
    })

    # Dispatch to agent
    case GoodwizardAgent.ask_sync(state.agent_pid, input, timeout: @ask_timeout) do
      {:ok, response} ->
        # Save assistant message to room
        Messaging.save_message(%{
          room_id: state.room_id,
          sender_id: "assistant",
          role: :assistant,
          content: [%{type: "text", text: response}]
        })

        IO.puts("\ngoodwizard> #{response}\n")
        {:ok, response}

      {:error, reason} ->
        IO.puts("\n[error] #{inspect(reason)}\n")
        {:error, reason}
    end
  end
end
