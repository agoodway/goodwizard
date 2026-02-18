defmodule Goodwizard.Scheduling.ScheduledTaskRegistry do
  @moduledoc """
  In-memory registry mapping `job_id -> scheduler_pid`.

  Monitors each registered scheduler process and auto-removes the mapping
  when the process terminates. Used by scheduling actions to look up and
  cancel scheduled tasks without going through the Jido executor's directive
  pipeline.
  """

  use GenServer

  require Logger

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc "Register a scheduler pid for the given job_id. Monitors the pid for auto-cleanup."
  @spec register(atom(), pid()) :: :ok
  def register(job_id, pid) when is_atom(job_id) and is_pid(pid) do
    GenServer.call(__MODULE__, {:register, job_id, pid})
  end

  @doc "Look up the scheduler pid for a job_id."
  @spec lookup(atom() | binary()) :: {:ok, pid()} | :error
  def lookup(job_id) do
    GenServer.call(__MODULE__, {:lookup, job_id})
  end

  @doc """
  Cancel a scheduled task by job_id.

  Looks up the scheduler pid, calls `Jido.Scheduler.cancel/1`, and removes
  the mapping. Returns `:ok` even if the job_id is not found (idempotent).
  """
  @spec cancel(atom() | binary()) :: :ok
  def cancel(job_id) do
    GenServer.call(__MODULE__, {:cancel, job_id})
  end

  # --- GenServer callbacks ---

  @impl true
  def init(:ok) do
    # State: %{jobs: %{job_id => {pid, monitor_ref}}}
    {:ok, %{jobs: %{}}}
  end

  @impl true
  def handle_call({:register, job_id, pid}, _from, state) do
    # Demonitor any existing registration for this job_id
    state = demonitor_job(state, job_id)

    ref = Process.monitor(pid)
    jobs = Map.put(state.jobs, job_id, {pid, ref})
    {:reply, :ok, %{state | jobs: jobs}}
  end

  def handle_call({:lookup, job_id}, _from, state) do
    job_id = normalize_job_id(job_id)

    case Map.get(state.jobs, job_id) do
      {pid, _ref} -> {:reply, {:ok, pid}, state}
      nil -> {:reply, :error, state}
    end
  end

  def handle_call({:cancel, job_id}, _from, state) do
    job_id = normalize_job_id(job_id)

    case Map.get(state.jobs, job_id) do
      {pid, ref} ->
        Process.demonitor(ref, [:flush])
        Jido.Scheduler.cancel(pid)
        {:reply, :ok, %{state | jobs: Map.delete(state.jobs, job_id)}}

      nil ->
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    # Find and remove the job whose monitor ref matches
    {removed, kept} =
      Enum.split_with(state.jobs, fn {_job_id, {_pid, r}} -> r == ref end)

    for {job_id, _} <- removed do
      Logger.warning(
        "ScheduledTaskRegistry: scheduler process #{inspect(pid)} for #{job_id} died: #{inspect(reason)}"
      )
    end

    {:noreply, %{state | jobs: Map.new(kept)}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # --- Private helpers ---

  defp demonitor_job(state, job_id) do
    case Map.get(state.jobs, job_id) do
      {_pid, ref} ->
        Process.demonitor(ref, [:flush])
        %{state | jobs: Map.delete(state.jobs, job_id)}

      nil ->
        state
    end
  end

  defp normalize_job_id(job_id) when is_atom(job_id), do: job_id

  defp normalize_job_id(job_id) when is_binary(job_id) do
    String.to_existing_atom(job_id)
  rescue
    ArgumentError -> job_id
  end
end
