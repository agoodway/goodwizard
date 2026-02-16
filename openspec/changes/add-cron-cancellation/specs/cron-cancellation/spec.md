## ADDED Requirements

### Requirement: Cancel a cron job by job_id

The system SHALL provide a `Goodwizard.Actions.Scheduling.CancelCron` action that accepts a `job_id` (string) and emits a `Directive.CronCancel` to stop the corresponding in-memory scheduler job. The action SHALL use `use Jido.Action` with name `cancel_cron_job`, a schema containing `job_id` (required, string), and a `run/2` callback that converts the string job_id to an atom and returns the `CronCancel` directive.

#### Scenario: Valid job_id cancels the cron job

- **WHEN** `CancelCron` is called with `job_id` set to `"cron_12345678"`
- **THEN** it SHALL convert the job_id to the atom `:cron_12345678`, emit a `Directive.CronCancel` with that job_id, and return `{:ok, %{cancelled: true, job_id: :cron_12345678}, [directive]}`

#### Scenario: Job_id provided as string is converted to atom

- **WHEN** `CancelCron` is called with `job_id` as a string `"cron_99887766"`
- **THEN** it SHALL convert the string to the atom `:cron_99887766` before building the `Directive.CronCancel`

#### Scenario: Nonexistent job_id is handled gracefully

- **WHEN** `CancelCron` is called with a `job_id` that does not correspond to any active cron job
- **THEN** it SHALL still emit the `Directive.CronCancel` directive and return success, because cancellation is idempotent and Jido handles unknown job_ids gracefully

### Requirement: CancelCron is registered in the Agent tools list

The `Goodwizard.Actions.Scheduling.CancelCron` module SHALL be added to the `tools:` list in `Goodwizard.Agent`, alongside the existing `Goodwizard.Actions.Scheduling.Cron` action.

#### Scenario: Agent starts with cancel_cron_job tool available

- **WHEN** the agent is initialized
- **THEN** `cancel_cron_job` SHALL appear in the agent's available tool list
