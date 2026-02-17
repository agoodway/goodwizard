defmodule Goodwizard.Actions.Scheduling.ListOneShotJobs do
  @moduledoc """
  Lists all persisted one-shot jobs.

  Reads job records from `OneShotStore` (file-backed) and returns them
  sorted by `fires_at` ascending, with task, channel, external_id, job_id,
  fires_at, and created_at. Job IDs can be used with `cancel_oneshot_job`.
  """

  use Jido.Action,
    name: "list_oneshot_jobs",
    description:
      "List all pending one-shot scheduled tasks. " <>
        "Returns job records from disk, each containing job_id, task, channel, " <>
        "external_id, fires_at, and created_at, sorted by fires_at ascending. " <>
        "Job IDs can be used with cancel_oneshot_job.",
    schema: []

  alias Goodwizard.Scheduling.OneShotStore

  @impl true
  def run(_params, _context) do
    case OneShotStore.list() do
      {:ok, jobs} -> {:ok, %{jobs: jobs, count: length(jobs)}}
      {:error, reason} -> {:error, "Failed to list one-shot jobs: #{inspect(reason)}"}
    end
  end
end
