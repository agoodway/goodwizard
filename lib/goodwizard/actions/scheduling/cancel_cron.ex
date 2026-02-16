defmodule Goodwizard.Actions.Scheduling.CancelCron do
  @moduledoc """
  Cancels a scheduled cron job by job_id.

  Emits a `Directive.CronCancel` for Jido's scheduler to process.
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
      job_id: [type: :string, required: true, doc: "The job_id to cancel (e.g. \"cron_12345678\")"]
    ]

  alias Jido.Agent.Directive

  @impl true
  def run(%{job_id: job_id}, _context) do
    atom_id = String.to_atom(job_id)
    directive = Directive.cron_cancel(atom_id)

    {:ok, %{cancelled: true, job_id: atom_id}, [directive]}
  end
end
