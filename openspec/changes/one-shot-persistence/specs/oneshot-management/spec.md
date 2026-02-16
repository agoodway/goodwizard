## ADDED Requirements

### Requirement: Users can cancel pending one-shot tasks

The system SHALL provide a `cancel_oneshot` action that cancels a pending one-shot task by `job_id`. Cancellation SHALL delete the persisted file and prevent the task from firing. If the job has already fired or does not exist, cancellation SHALL succeed silently (idempotent).

#### Scenario: Cancel a pending one-shot job

- **WHEN** a user cancels a pending one-shot job by `job_id`
- **THEN** the persisted `oneshot_<hash>.json` file is deleted
- **AND** the in-memory timer is cancelled (if still pending)
- **AND** the action returns `{:ok, %{cancelled: true, job_id: job_id}}`

#### Scenario: Cancel an already-fired or non-existent job

- **WHEN** a user cancels a job_id that does not exist or has already fired
- **THEN** the action returns `{:ok, %{cancelled: true, job_id: job_id}}`
- **AND** no error is raised

#### Scenario: Invalid job_id format is rejected

- **WHEN** a user cancels with a job_id that does not match `oneshot_<16hex>` format
- **THEN** the action returns an error indicating invalid job_id

### Requirement: Users can list pending one-shot tasks

The system SHALL provide a `list_oneshot_jobs` action that returns all persisted one-shot job records sorted by `fires_at` ascending.

#### Scenario: List pending one-shot jobs

- **WHEN** a user lists one-shot jobs and 3 jobs are persisted
- **THEN** the action returns all 3 job records with `job_id`, `task`, `room_id`, `fires_at`, and `created_at`
- **AND** the records are sorted by `fires_at` ascending (soonest first)

#### Scenario: List when no one-shot jobs exist

- **WHEN** a user lists one-shot jobs and the `scheduling/oneshot/` directory is empty or missing
- **THEN** the action returns `{:ok, %{jobs: []}}`

### Requirement: One-shot timer references are tracked for cancellation

The system SHALL track `:timer` references in a registry (or extend `CronRegistry`) so that `cancel_oneshot` can cancel the in-memory timer in addition to deleting the persisted file.

#### Scenario: Timer is cancelled when job is cancelled

- **WHEN** a one-shot job is scheduled and then cancelled before firing
- **THEN** the `:timer` reference is used to cancel the pending timer
- **AND** the task does NOT fire

#### Scenario: Timer reference is cleaned up after firing

- **WHEN** a one-shot job fires
- **THEN** the timer reference is removed from the registry
