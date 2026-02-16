defmodule Goodwizard.Actions.Scheduling.ListCronJobs do
  @moduledoc """
  Lists all active cron jobs for the current agent.

  Reads the `cron_jobs` map from `AgentServer` state and returns
  job descriptors with job_id and active status.
  """

  use Jido.Action,
    name: "list_cron_jobs",
    description:
      "List all active cron jobs scheduled for this agent. " <>
        "Returns job IDs that can be used with cancel_cron_job. " <>
        "Each job entry includes the job_id (string) and whether the " <>
        "scheduler process is still alive.",
    schema: []

  require Logger

  @impl true
  def run(_params, context) do
    agent_id = context[:agent_id]

    case get_cron_jobs(agent_id) do
      {:ok, cron_jobs} ->
        jobs =
          Enum.map(cron_jobs, fn {job_id, pid} ->
            %{
              job_id: to_string(job_id),
              active: is_pid(pid) and Process.alive?(pid)
            }
          end)

        {:ok, %{jobs: jobs, count: length(jobs)}}

      {:error, reason} ->
        Logger.warning(fn ->
          "[ListCronJobs] Failed to read cron_jobs: #{inspect(reason)}"
        end)

        {:ok, %{jobs: [], count: 0}}
    end
  end

  defp get_cron_jobs(nil), do: {:ok, %{}}

  defp get_cron_jobs(agent_id) do
    case Jido.AgentServer.state(agent_id) do
      {:ok, state} -> {:ok, state.cron_jobs || %{}}
      {:error, _} = err -> err
    end
  end
end
