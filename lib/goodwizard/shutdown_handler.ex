defmodule Goodwizard.ShutdownHandler do
  @moduledoc """
  Handles graceful shutdown by saving all active sessions before exit.

  Traps exits so it receives a `terminate/2` callback from the supervisor.
  On shutdown, iterates active agent processes and flushes their sessions
  to JSONL files. Respects a 30-second timeout.
  """
  use GenServer

  require Logger

  @shutdown_timeout 30_000

  @doc "Starts the shutdown handler and links to the calling process."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)
    {:ok, %{}}
  end

  @impl true
  def terminate(reason, _state) do
    Logger.info("Graceful shutdown initiated, reason=#{inspect(reason)}")
    flush_sessions()
    Logger.info("Graceful shutdown complete")
    :ok
  end

  alias Goodwizard.Plugins

  defp flush_sessions do
    agents =
      try do
        Goodwizard.Jido.list_agents()
      rescue
        _ -> []
      catch
        :exit, _ -> []
      end

    Logger.info("Flushing sessions for #{length(agents)} agent(s)")

    sessions_dir = resolve_sessions_dir()

    task =
      Task.async(fn ->
        for {agent_id, pid} <- agents do
          try do
            # Get agent state and save session
            state = :sys.get_state(pid, @shutdown_timeout)
            session_key = Map.get(state.state, :session_key, "default")

            case Plugins.Session.save_session(sessions_dir, session_key, state.state) do
              :ok ->
                Logger.debug("Session saved for agent #{agent_id}")

              {:error, reason} ->
                Logger.warning("Failed to save session for agent #{agent_id}: #{inspect(reason)}")
            end
          rescue
            e ->
              Logger.warning(
                "Error saving session for agent #{agent_id}: #{Exception.message(e)}"
              )
          catch
            :exit, reason ->
              Logger.warning("Agent #{agent_id} unavailable during shutdown: #{inspect(reason)}")
          end
        end
      end)

    case Task.yield(task, @shutdown_timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, _} -> :ok
      nil -> Logger.warning("Session flush timed out after #{@shutdown_timeout}ms")
    end
  end

  defp resolve_sessions_dir do
    Goodwizard.Config.sessions_dir()
  rescue
    _ ->
      fallback = Path.expand("priv/workspace/sessions")

      Logger.warning(
        "Config unavailable during shutdown; using fallback sessions_dir=#{fallback}"
      )

      fallback
  catch
    :exit, _ ->
      fallback = Path.expand("priv/workspace/sessions")

      Logger.warning(
        "Config unavailable during shutdown; using fallback sessions_dir=#{fallback}"
      )

      fallback
  end
end
