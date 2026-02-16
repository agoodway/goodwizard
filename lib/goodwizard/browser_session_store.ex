defmodule Goodwizard.BrowserSessionStore do
  @moduledoc """
  ETS-backed store for browser sessions, keyed by agent ID.

  The ReAct strategy's `run_tool_context` is set once at `react_start` and never
  updated between iterations. When Navigate returns an updated session (with
  `current_url` set), subsequent browser actions still see the stale session.

  This store acts as a side-channel: Navigate wrappers write the updated session
  here, and `on_before_cmd(:react_llm_result)` reads it back into the strategy
  state before `lift_directives` builds ToolExec directives.
  """

  use GenServer

  @table __MODULE__

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Store a browser session for the given agent."
  @spec put(String.t(), JidoBrowser.Session.t()) :: :ok
  def put(agent_id, %JidoBrowser.Session{} = session) do
    :ets.insert(@table, {agent_id, session})
    :ok
  end

  @doc "Retrieve the latest browser session for the given agent. Returns nil on miss."
  @spec get(String.t()) :: JidoBrowser.Session.t() | nil
  def get(agent_id) do
    case :ets.lookup(@table, agent_id) do
      [{^agent_id, session}] -> session
      [] -> nil
    end
  end

  @doc "Remove the stored session for the given agent."
  @spec delete(String.t()) :: :ok
  def delete(agent_id) do
    :ets.delete(@table, agent_id)
    :ok
  end

  # GenServer callbacks

  @impl true
  def init(_) do
    table = :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, table}
  end
end
