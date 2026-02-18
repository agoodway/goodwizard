## ADDED Requirements

### Requirement: Cancel a scheduled task by job_id

The system SHALL provide a `Goodwizard.Actions.Scheduling.CancelScheduledTask` action that accepts a `job_id` (string) and emits a `Directive.CronCancel` to stop the corresponding in-memory scheduler job. The action SHALL use `use Jido.Action` with name `cancel_scheduled_task`, a schema containing `job_id` (required, string), and a `run/2` callback that converts the string job_id to an atom and returns the `CronCancel` directive.

#### Scenario: Valid job_id cancels the scheduled task

- **WHEN** `CancelScheduledTask` is called with `job_id` set to `"scheduled_task_12345678"`
- **THEN** it SHALL convert the job_id to the atom `:scheduled_task_12345678`, emit a `Directive.CronCancel` with that job_id, and return `{:ok, %{cancelled: true, job_id: :scheduled_task_12345678}, [directive]}`

#### Scenario: Job_id provided as string is converted to atom

- **WHEN** `CancelScheduledTask` is called with `job_id` as a string `"scheduled_task_99887766"`
- **THEN** it SHALL convert the string to the atom `:scheduled_task_99887766` before building the `Directive.CronCancel`

#### Scenario: Nonexistent job_id is handled gracefully

- **WHEN** `CancelScheduledTask` is called with a `job_id` that does not correspond to any active scheduled task
- **THEN** it SHALL still emit the `Directive.CronCancel` directive and return success, because cancellation is idempotent and Jido handles unknown job_ids gracefully

### Requirement: CancelScheduledTask is registered in the Agent tools list

The `Goodwizard.Actions.Scheduling.CancelScheduledTask` module SHALL be added to the `tools:` list in `Goodwizard.Agent`, alongside the existing `Goodwizard.Actions.Scheduling.ScheduledTask` action.

#### Scenario: Agent starts with cancel_scheduled_task tool available

- **WHEN** the agent is initialized
- **THEN** `cancel_scheduled_task` SHALL appear in the agent's available tool list
