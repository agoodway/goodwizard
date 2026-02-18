defmodule Goodwizard.Actions.Scheduling.CancelScheduledTask do
  @moduledoc """
  Cancels a scheduled recurring task by job_id.

  Removes the persisted job file via `ScheduledTaskStore.delete/1` and cancels the
  in-memory scheduler process via `ScheduledTaskRegistry.cancel/1`.
  Cancellation is idempotent — cancelling a nonexistent job is a no-op.
  """

  use Jido.Action,
    name: "cancel_scheduled_task",
    description:
      "Cancel a scheduled recurring task by its job_id. " <>
        "Use list_scheduled_tasks first to find the job_id of the job you want to cancel. " <>
        "Job IDs look like \"scheduled_task_12345678\". Cancellation is idempotent — " <>
        "cancelling a job that doesn't exist is safe and returns success.",
    schema: [
      job_id: [
        type: :string,
        required: true,
        doc: "The job_id to cancel (e.g. \"scheduled_task_12345678\")"
      ]
    ]

  alias Goodwizard.Scheduling.{ScheduledTaskRegistry, ScheduledTaskStore}

  @impl true
  def run(%{job_id: job_id}, _context) do
    # Delete the persisted file (idempotent — :ok if missing)
    ScheduledTaskStore.delete(job_id)

    # Resolve to an existing atom if possible (matching the original registration),
    # but never create new atoms from user input to avoid atom table exhaustion.
    cancel_id =
      try do
        String.to_existing_atom(job_id)
      rescue
        ArgumentError -> job_id
      end

    # Cancel the in-memory scheduler process (idempotent — :ok if not found)
    ScheduledTaskRegistry.cancel(cancel_id)

    {:ok, %{cancelled: true, job_id: cancel_id}}
  end
end
