defmodule Goodwizard.Browser.Serializer do
  @moduledoc """
  GenServer that serializes browser commands through a single process.

  Vibium's clicker processes deadlock when multiple browser actions execute
  concurrently (all timeout at 30s). This GenServer ensures only one browser
  command runs at a time by funneling all calls through `GenServer.call/3`.
  """

  use GenServer

  @default_timeout 120_000

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Execute a function serialized through the browser command queue.

  The timeout is set high (120s) to accommodate queued commands — up to
  4 commands at 30s each can be waiting in the mailbox.
  """
  @spec execute((-> term()), timeout()) :: term()
  def execute(fun, timeout \\ @default_timeout) when is_function(fun, 0) do
    GenServer.call(__MODULE__, {:execute, fun}, timeout)
  end

  # GenServer callbacks

  @impl true
  def init(_), do: {:ok, %{}}

  @impl true
  def handle_call({:execute, fun}, _from, state) do
    result = fun.()
    {:reply, result, state}
  end
end
