defmodule Goodwizard.Scheduling.ScheduledTaskLoader do
  @moduledoc """
  Reloads persisted scheduled tasks on application startup.

  Reads all persisted jobs from `ScheduledTaskStore.load_all/0` and re-registers
  each one with the Jido scheduler by starting a dedicated scheduled task agent
  and emitting `Directive.Cron` for each job through it.

  Malformed files are skipped with a warning — the agent starts normally
  even if some job files are corrupt.
  """

  require Logger

  alias Goodwizard.Agent, as: GoodwizardAgent
  alias Goodwizard.Scheduling.{ScheduledTaskRegistry, ScheduledTaskStore}
  alias Jido.Agent.Directive

  @doc """
  Reloads all persisted scheduled tasks.

  Starts a dedicated agent to hold the cron registrations, reads all
  persisted jobs from disk, and re-emits `Directive.Cron` for each.

  Returns `{:ok, count}` with the number of jobs reloaded, or
  `{:error, reason}` if the agent couldn't be started.
  """
  @spec reload() :: {:ok, non_neg_integer()} | {:error, term()}
  def reload do
    case ScheduledTaskStore.load_all() do
      {:ok, []} ->
        Logger.info("ScheduledTaskLoader: no persisted scheduled tasks to reload")
        {:ok, 0}

      {:ok, jobs} ->
        reload_jobs(jobs)
    end
  end

  defp reload_jobs(jobs) do
    agent_id = "scheduled_task:loader:#{System.unique_integer([:positive])}"

    case Goodwizard.Jido.start_agent(GoodwizardAgent,
           id: agent_id,
           initial_state: %{
             workspace: Goodwizard.Config.workspace(),
             channel: "scheduled_tasks",
             chat_id: "loader"
           }
         ) do
      {:ok, pid} ->
        count = register_jobs(pid, agent_id, jobs)
        Logger.info("ScheduledTaskLoader: reloaded #{count} scheduled task(s)")
        {:ok, count}

      {:error, reason} ->
        Logger.error(
          "ScheduledTaskLoader: failed to start scheduled task agent: #{inspect(reason)}"
        )

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

  # Job IDs are created as :"scheduled_task_<16hex>" — only allow that format.
  @job_id_pattern ~r/\Ascheduled_task_[0-9a-f]{16}\z/

  defp register_job(_pid, agent_id, job) do
    with {:ok, schedule} <- extract_field(job, "schedule"),
         {:ok, task} <- extract_field(job, "task"),
         {:ok, channel, external_id} <- extract_channel(job),
         {:ok, job_id} <- validate_job_id(job["job_id"]) do
      mode = job["mode"] || "isolated"
      model = job["model"]

      message = build_message(task, channel, external_id, mode, model)
      directive = Directive.cron(schedule, message, job_id: job_id)

      # Use the Jido scheduler directly to register the job,
      # mirroring what DirectiveExec.Cron does internally.
      signal = build_scheduled_task_tick_signal(message, job_id, agent_id)

      start_scheduler(agent_id, signal, directive.cron, job_id, schedule)
    else
      {:error, reason} ->
        Logger.warning("ScheduledTaskLoader: skipping malformed job record: #{inspect(reason)}")
        :skip
    end
  end

  # New format: channel + external_id stored directly on the job.
  defp extract_channel(%{"channel" => ch, "external_id" => eid})
       when is_binary(ch) and ch != "" and is_binary(eid) and eid != "" do
    {:ok, ch, eid}
  end

  # Legacy format: room_id only. Pass through as-is so old jobs still load
  # (they'll have the same restart-delivery issue until re-scheduled).
  defp extract_channel(%{"room_id" => room_id}) when is_binary(room_id) and room_id != "" do
    Logger.warning(
      "ScheduledTaskLoader: job uses legacy room_id format — re-schedule to get restart-safe delivery"
    )

    {:ok, "_legacy", room_id}
  end

  defp extract_channel(_), do: {:error, "missing channel/external_id (or legacy room_id)"}

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

  defp build_message(task, channel, external_id, mode, model) do
    base = %{
      type: "scheduled_task.task",
      task: task,
      channel: channel,
      external_id: external_id,
      mode: mode
    }

    if mode == "isolated" && model do
      Map.put(base, :model, model)
    else
      base
    end
  end

  defp start_scheduler(agent_id, signal, scheduled_task_expr, job_id, schedule) do
    tick_fn = fn ->
      dispatch_tick(agent_id, signal)
      :ok
    end

    case Jido.Scheduler.run_every(tick_fn, scheduled_task_expr, []) do
      {:ok, sched_pid} ->
        # SchedEx.Runner uses GenServer.start_link, linking to the caller.
        # ScheduledTaskLoader runs inside a startup Task that exits after boot.
        # Unlink so the SchedEx runner outlives the caller.
        Process.unlink(sched_pid)
        ScheduledTaskRegistry.register(job_id, sched_pid)
        Logger.debug("ScheduledTaskLoader: registered #{job_id} (#{schedule})")
        :ok

      {:error, reason} ->
        Logger.warning("ScheduledTaskLoader: failed to register #{job_id}: #{inspect(reason)}")
        :skip
    end
  end

  defp dispatch_tick(agent_id, signal) do
    case Goodwizard.Jido.whereis(agent_id) do
      pid when is_pid(pid) -> Jido.AgentServer.cast(pid, signal)
      nil -> Logger.warning("ScheduledTaskLoader: agent #{agent_id} not found, skipping tick")
    end
  end

  defp build_scheduled_task_tick_signal(message, job_id, agent_id) do
    Jido.Signal.new!("jido.scheduled_task_tick", %{job_id: job_id, message: message},
      source: "/agent/#{agent_id}"
    )
  end
end
