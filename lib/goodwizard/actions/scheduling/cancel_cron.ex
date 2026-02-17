defmodule Goodwizard.Actions.Scheduling.CancelCron do
  @moduledoc """
  Cancels a scheduled cron job by job_id.

  Removes the persisted job file via `CronStore.delete/1` and cancels the
  in-memory scheduler process via `CronRegistry.cancel/1`.
  Cancellation is idempotent — cancelling a nonexistent job is a no-op.
  """

  use Jido.Action,
    name: "cancel_cron_job",
    description:
      "Cancel a scheduled recurring cron job by its job_id. " <>
        "Use list_cron_jobs first to find the job_id of the job you want to cancel. " <>
        "Job IDs look like \"cron_12345678\". Cancellation is idempotent — " <>
        "cancelling a job that doesn't exist is safe and returns success.",
    schema: [
      job_id: [
        type: :string,
        required: true,
        doc: "The job_id to cancel (e.g. \"cron_12345678\")"
      ]
    ]

  alias Goodwizard.Scheduling.{CronRegistry, CronStore}

  @impl true
  def run(%{job_id: job_id}, _context) do
    # Delete the persisted file (idempotent — :ok if missing)
    CronStore.delete(job_id)

    # Resolve to an existing atom if possible (matching the original registration),
    # but never create new atoms from user input to avoid atom table exhaustion.
    cancel_id =
      try do
        String.to_existing_atom(job_id)
      rescue
        ArgumentError -> job_id
      end

    # Cancel the in-memory scheduler process (idempotent — :ok if not found)
    CronRegistry.cancel(cancel_id)

    {:ok, %{cancelled: true, job_id: cancel_id}}
  end
end
