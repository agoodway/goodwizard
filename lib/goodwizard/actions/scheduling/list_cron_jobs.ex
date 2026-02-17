defmodule Goodwizard.Actions.Scheduling.ListCronJobs do
  @moduledoc """
  Lists all persisted cron jobs.

  Reads job records from `CronStore` (file-backed) and returns them
  as a list with schedule, task, channel, external_id, job_id, and created_at.
  """

  use Jido.Action,
    name: "list_cron_jobs",
    description:
      "List all scheduled cron jobs. " <>
        "Returns job records from disk, each containing job_id, schedule, task, " <>
        "channel, external_id, and created_at. Job IDs can be used with cancel_cron_job.",
    schema: []

  alias Goodwizard.Scheduling.CronStore

  @impl true
  def run(_params, _context) do
    {:ok, jobs} = CronStore.list()
    {:ok, %{jobs: jobs, count: length(jobs)}}
  end
end
