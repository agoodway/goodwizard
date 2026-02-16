defmodule Goodwizard.Scheduling.CronLoader do
  @moduledoc """
  Reloads persisted cron jobs on application startup.

  Reads all persisted jobs from `CronStore.load_all/0` and re-registers
  each one with the Jido scheduler by starting a dedicated cron agent
  and emitting `Directive.Cron` for each job through it.

  Malformed files are skipped with a warning — the agent starts normally
  even if some job files are corrupt.
  """

  require Logger

  alias Goodwizard.Agent, as: GoodwizardAgent
  alias Goodwizard.Scheduling.CronStore
  alias Jido.Agent.Directive

  @doc """
  Reloads all persisted cron jobs.

  Starts a dedicated agent to hold the cron registrations, reads all
  persisted jobs from disk, and re-emits `Directive.Cron` for each.

  Returns `{:ok, count}` with the number of jobs reloaded, or
  `{:error, reason}` if the agent couldn't be started.
  """
  @spec reload() :: {:ok, non_neg_integer()} | {:error, term()}
  def reload do
    case CronStore.load_all() do
      {:ok, []} ->
        Logger.info("CronLoader: no persisted cron jobs to reload")
        {:ok, 0}

      {:ok, jobs} ->
        reload_jobs(jobs)
    end
  end

  defp reload_jobs(jobs) do
    agent_id = "cron:loader:#{System.unique_integer([:positive])}"

    case Goodwizard.Jido.start_agent(GoodwizardAgent,
           id: agent_id,
           initial_state: %{
             workspace: Goodwizard.Config.workspace(),
             channel: "cron",
             chat_id: "loader"
           }
         ) do
      {:ok, pid} ->
        count = register_jobs(pid, agent_id, jobs)
        Logger.info("CronLoader: reloaded #{count} cron job(s)")
        {:ok, count}

      {:error, reason} ->
        Logger.error("CronLoader: failed to start cron agent: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp register_jobs(pid, agent_id, jobs) do
    Enum.reduce(jobs, 0, fn job, count ->
      case register_job(pid, agent_id, job) do
        :ok -> count + 1
        :skip -> count
      end
    end)
  end

  # Job IDs are created as :"cron_<16hex>" — only allow that format.
  @job_id_pattern ~r/\Acron_[0-9a-f]{16}\z/

  defp register_job(_pid, agent_id, job) do
    with {:ok, schedule} <- extract_field(job, "schedule"),
         {:ok, task} <- extract_field(job, "task"),
         {:ok, room_id} <- extract_field(job, "room_id"),
         {:ok, job_id} <- validate_job_id(job["job_id"]) do
      mode = job["mode"] || "isolated"
      model = job["model"]

      message = build_message(task, room_id, mode, model)
      directive = Directive.cron(schedule, message, job_id: job_id)

      # Use the Jido scheduler directly to register the job,
      # mirroring what DirectiveExec.Cron does internally.
      signal = build_cron_tick_signal(message, job_id, agent_id)

      case Jido.Scheduler.run_every(
             fn ->
               _ = Jido.AgentServer.cast(agent_id, signal)
               :ok
             end,
             directive.cron,
             []
           ) do
        {:ok, _sched_pid} ->
          Logger.debug("CronLoader: registered #{job_id} (#{schedule})")
          :ok

        {:error, reason} ->
          Logger.warning(
            "CronLoader: failed to register #{job_id}: #{inspect(reason)}"
          )

          :skip
      end
    else
      {:error, reason} ->
        Logger.warning("CronLoader: skipping malformed job record: #{inspect(reason)}")
        :skip
    end
  end

  defp validate_job_id(nil), do: {:error, "missing field: job_id"}

  defp validate_job_id(job_id_str) when is_binary(job_id_str) do
    if Regex.match?(@job_id_pattern, job_id_str) do
      {:ok, String.to_atom(job_id_str)}
    else
      {:error, "invalid job_id format: #{inspect(job_id_str)}"}
    end
  end

  defp extract_field(job, field) do
    case Map.get(job, field) do
      nil -> {:error, "missing field: #{field}"}
      "" -> {:error, "empty field: #{field}"}
      value -> {:ok, value}
    end
  end

  defp build_message(task, room_id, mode, model) do
    base = %{type: "cron.task", task: task, room_id: room_id, mode: mode}

    if mode == "isolated" && model do
      Map.put(base, :model, model)
    else
      base
    end
  end

  defp build_cron_tick_signal(message, job_id, agent_id) do
    Jido.AgentServer.Signal.CronTick.new!(
      %{job_id: job_id, message: message},
      source: "/agent/#{agent_id}"
    )
  end
end
