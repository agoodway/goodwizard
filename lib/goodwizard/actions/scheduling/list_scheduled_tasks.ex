defmodule Goodwizard.Actions.Scheduling.ListScheduledTasks do
  @moduledoc """
  Lists all persisted scheduled tasks.

  Reads job records from `ScheduledTaskStore` (file-backed) and returns them
  as a list with schedule, task, channel, external_id, job_id, and created_at.
  """

  use Jido.Action,
    name: "list_scheduled_tasks",
    description:
      "List all scheduled recurring tasks. " <>
        "Returns job records from disk, each containing job_id, schedule, task, " <>
        "channel, external_id, and created_at. Job IDs can be used with cancel_scheduled_task.",
    schema: []

  alias Goodwizard.Scheduling.ScheduledTaskStore

  @impl true
  def run(_params, _context) do
    {:ok, jobs} = ScheduledTaskStore.list()
    {:ok, %{jobs: jobs, count: length(jobs)}}
  end
end
