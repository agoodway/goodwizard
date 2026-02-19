defmodule Goodwizard.Scheduling.OneTimeRegistry do
  @moduledoc """
  In-memory registry mapping `job_id -> timer_ref` for one-time tasks.

  Tracks `:timer` references so one-time tasks can be cancelled before
  they fire. Auto-removes entries when deregistered (after fire or cancel).
  """

  use GenServer

  # --- Public API ---

  @type timer_ref :: :timer.tref() | reference()

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc "Register a timer reference for the given job_id."
  @spec register(atom(), timer_ref()) :: :ok
  def register(job_id, timer_ref) when is_atom(job_id) do
    GenServer.call(__MODULE__, {:register, job_id, timer_ref})
  end

  @doc "Look up the timer reference for a job_id."
  @spec lookup(atom() | binary()) :: {:ok, timer_ref()} | :error
  def lookup(job_id) do
    GenServer.call(__MODULE__, {:lookup, job_id})
  end

  @doc """
  Cancel a one-time task by job_id.

  Cancels the timer via `:timer.cancel/1` and removes the mapping.
  Returns `:ok` even if the job_id is not found (idempotent).
  """
  @spec cancel(atom() | binary()) :: :ok
  def cancel(job_id) do
    GenServer.call(__MODULE__, {:cancel, job_id})
  end

  @doc "Remove a job_id from the registry without cancelling the timer."
  @spec deregister(atom() | binary()) :: :ok
  def deregister(job_id) do
    GenServer.call(__MODULE__, {:deregister, job_id})
  end

  # --- GenServer callbacks ---

  @impl true
  def init(:ok) do
    {:ok, %{jobs: %{}}}
  end

  @impl true
  def handle_call({:register, job_id, timer_ref}, _from, state) do
    case Map.get(state.jobs, job_id) do
      nil -> :ok
      old_ref -> :timer.cancel(old_ref)
    end

    jobs = Map.put(state.jobs, job_id, timer_ref)
    {:reply, :ok, %{state | jobs: jobs}}
  end

  def handle_call({:lookup, job_id}, _from, state) do
    job_id = normalize_job_id(job_id)

    case Map.get(state.jobs, job_id) do
      nil -> {:reply, :error, state}
      timer_ref -> {:reply, {:ok, timer_ref}, state}
    end
  end

  def handle_call({:cancel, job_id}, _from, state) do
    job_id = normalize_job_id(job_id)

    case Map.get(state.jobs, job_id) do
      nil ->
        {:reply, :ok, state}

      timer_ref ->
        :timer.cancel(timer_ref)
        {:reply, :ok, %{state | jobs: Map.delete(state.jobs, job_id)}}
    end
  end

  def handle_call({:deregister, job_id}, _from, state) do
    job_id = normalize_job_id(job_id)
    {:reply, :ok, %{state | jobs: Map.delete(state.jobs, job_id)}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # --- Private helpers ---

  defp normalize_job_id(job_id) when is_atom(job_id), do: job_id

  defp normalize_job_id(job_id) when is_binary(job_id) do
    String.to_existing_atom(job_id)
  rescue
    ArgumentError -> job_id
  end
end
