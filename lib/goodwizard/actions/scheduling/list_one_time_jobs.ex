defmodule Goodwizard.Actions.Scheduling.ListOneTimeJobs do
  @moduledoc """
  Lists all persisted one-time tasks.

  Reads job records from `OneTimeStore` (file-backed) and returns them
  sorted by `fires_at` ascending, with task, channel, external_id, job_id,
  fires_at, and created_at. Job IDs can be used with `cancel_one_time_job`.
  """

  use Jido.Action,
    name: "list_one_time_jobs",
    description:
      "List all pending one-time tasks. " <>
        "Returns job records from disk, each containing job_id, task, channel, " <>
        "external_id, fires_at, and created_at, sorted by fires_at ascending. " <>
        "Job IDs can be used with cancel_one_time_job.",
    schema: []

  alias Goodwizard.Scheduling.OneTimeStore

  @impl true
  def run(_params, _context) do
    case OneTimeStore.list() do
      {:ok, jobs} -> {:ok, %{jobs: jobs, count: length(jobs)}}
      {:error, reason} -> {:error, "Failed to list one-time tasks: #{inspect(reason)}"}
    end
  end
end
