## ADDED Requirements

### Requirement: Scheduled tasks are persisted to disk on creation

The system SHALL save each scheduled task to a JSON file in `workspace/scheduling/scheduled_tasks/` when the `schedule_scheduled_task` action successfully validates and schedules the job. The file SHALL be named `<job_id>.json` and contain the schedule, task, room_id, job_id, and a created_at timestamp.

#### Scenario: Job is saved after successful scheduling

- **WHEN** a user schedules a scheduled task with schedule `0 9 * * *`, task `Daily report`, and room_id `cli:heartbeat`
- **THEN** the system creates a file at `workspace/scheduling/scheduled_tasks/<job_id>.json` containing the job's schedule, task, room_id, job_id, and created_at fields

#### Scenario: Job file is not created on validation failure

- **WHEN** a user attempts to schedule a scheduled task with an invalid expression like `bad * * *`
- **THEN** the system returns a validation error and no file is written to disk

### Requirement: Scheduled tasks are reloaded on startup

The system SHALL read all JSON files from `workspace/scheduling/scheduled_tasks/` on agent startup and re-register each one with the Jido scheduler by emitting a `Directive.Cron` for each persisted job.

#### Scenario: Persisted jobs are restored after restart

- **WHEN** the agent starts and `workspace/scheduling/scheduled_tasks/` contains two job files
- **THEN** the system registers both jobs with the scheduler and they fire on their configured schedules

#### Scenario: Startup succeeds with no persisted jobs

- **WHEN** the agent starts and `workspace/scheduling/scheduled_tasks/` is empty or does not exist
- **THEN** the system starts normally with no scheduled tasks registered

#### Scenario: Malformed job files are skipped

- **WHEN** the agent starts and a file in `workspace/scheduling/scheduled_tasks/` contains invalid JSON
- **THEN** the system logs a warning and skips that file without crashing

### Requirement: Scheduled tasks can be cancelled and removed from disk

The system SHALL provide a `cancel_scheduled_task` action that accepts a `job_id`, removes the corresponding file from `workspace/scheduling/scheduled_tasks/`, and emits a `Directive.CronCancel` to stop the in-memory scheduler.

#### Scenario: Cancel removes file and stops scheduler

- **WHEN** a user cancels a scheduled task with a valid `job_id` that exists on disk
- **THEN** the system deletes the file at `workspace/scheduling/scheduled_tasks/<job_id>.json` and cancels the in-memory scheduler job

#### Scenario: Cancel with unknown job_id

- **WHEN** a user cancels a scheduled task with a `job_id` that has no corresponding file
- **THEN** the system still emits the cancel directive (to handle orphaned in-memory jobs) and returns success

### Requirement: Active scheduled tasks can be listed

The system SHALL provide a `list_scheduled_tasks` action that reads all persisted job files from `workspace/scheduling/scheduled_tasks/` and returns them as a list of job records.

#### Scenario: List returns all persisted jobs

- **WHEN** a user requests the list of scheduled tasks and three job files exist on disk
- **THEN** the system returns a list of three job records, each containing schedule, task, room_id, job_id, and created_at

#### Scenario: List returns empty when no jobs exist

- **WHEN** a user requests the list of scheduled tasks and the directory is empty
- **THEN** the system returns an empty list
