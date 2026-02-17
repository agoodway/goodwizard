defmodule Goodwizard.Actions.Scheduling.CancelOneShot do
  @moduledoc """
  Cancels a pending one-shot job by job_id.

  Cancels the in-memory timer via `OneShotRegistry.cancel/1` and removes
  the persisted job file via `OneShotStore.delete/1`.
  Cancellation is idempotent — cancelling a nonexistent or already-fired
  job is a no-op.
  """

  use Jido.Action,
    name: "cancel_oneshot_job",
    description:
      "Cancel a pending one-shot scheduled task by its job_id. " <>
        "Use list_oneshot_jobs first to find the job_id. " <>
        "Job IDs look like \"oneshot_abcdef1234567890\". Cancellation is idempotent — " <>
        "cancelling a job that doesn't exist or has already fired is safe and returns success.",
    schema: [
      job_id: [
        type: :string,
        required: true,
        doc: "The job_id to cancel (e.g. \"oneshot_abcdef1234567890\")"
      ]
    ]

  alias Goodwizard.Scheduling.{OneShotStore, OneShotRegistry}

  @impl true
  def run(%{job_id: job_id}, _context) do
    # Delete the persisted file (idempotent — :ok if missing)
    OneShotStore.delete(job_id)

    # Resolve to an existing atom if possible (matching the original registration),
    # but never create new atoms from user input to avoid atom table exhaustion.
    cancel_id =
      try do
        String.to_existing_atom(job_id)
      rescue
        ArgumentError -> job_id
      end

    # Cancel the in-memory timer (idempotent — :ok if not found)
    OneShotRegistry.cancel(cancel_id)

    {:ok, %{cancelled: true, job_id: to_string(cancel_id)}}
  end
end
