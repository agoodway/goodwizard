## ADDED Requirements

### Requirement: One-time tasks are persisted to disk on scheduling

The system SHALL persist each one-time task as a JSON file under `workspace/scheduling/one_time/<job_id>.json` immediately after `:timer.apply_after` succeeds. The record SHALL contain: `job_id`, `task`, `room_id`, `fires_at` (ISO 8601 UTC), and `created_at` (ISO 8601 UTC).

#### Scenario: Successful one-time task scheduling persists to disk

- **WHEN** a one-time task is scheduled with `delay_minutes: 30` and `task: "Send report"`
- **THEN** a JSON file `one_time_<hash>.json` is created under `workspace/scheduling/one_time/`
- **AND** the file contains `job_id`, `task`, `room_id`, `fires_at`, and `created_at` fields

#### Scenario: Scheduling with `at` parameter persists fires_at directly

- **WHEN** a one-time task is scheduled with `at: "2026-02-16T15:00:00Z"`
- **THEN** the persisted record's `fires_at` field equals `"2026-02-16T15:00:00Z"`

### Requirement: Persisted one-time tasks are reloaded on startup

The system SHALL reload all persisted one-time tasks from disk during application startup. For each job where `fires_at` is in the future, the system SHALL schedule the job via `:timer.apply_after` with the remaining delay calculated from `fires_at - now`.

#### Scenario: Pending one-time task survives restart

- **WHEN** the application restarts with a persisted one-time task whose `fires_at` is 20 minutes in the future
- **THEN** the job is re-scheduled with a delay of approximately 20 minutes
- **AND** the job fires at approximately the original `fires_at` time

#### Scenario: Expired one-time task is discarded on restart

- **WHEN** the application restarts with a persisted one-time task whose `fires_at` is in the past
- **THEN** the persisted file is deleted
- **AND** the job is NOT re-scheduled
- **AND** a warning is logged

### Requirement: Persisted file is auto-deleted after firing

The system SHALL delete the persisted JSON file for a one-time task after its signal is delivered to the agent. If file deletion fails, the job SHALL be discarded as expired on next reload.

#### Scenario: File cleanup after successful delivery

- **WHEN** a one-time task fires and the signal is delivered to the agent
- **THEN** the corresponding `one_time_<hash>.json` file is deleted from disk

#### Scenario: File cleanup when agent is not found

- **WHEN** a one-time task fires but the target agent is not running
- **THEN** the corresponding `one_time_<hash>.json` file is still deleted from disk
- **AND** a warning is logged

### Requirement: OneTimeStore validates job IDs against path traversal

The system SHALL reject job IDs that contain `..`, `/`, null bytes, or exceed 255 bytes. This prevents directory traversal attacks through crafted job IDs.

#### Scenario: Path traversal in job ID is rejected

- **WHEN** a save is attempted with job_id `"../../../etc/passwd"`
- **THEN** the save returns `{:error, :path_traversal}`

### Requirement: Malformed job files are skipped during reload

The system SHALL skip malformed JSON files during startup reload with a logged warning, without crashing. Valid jobs in the same directory SHALL still be loaded.

#### Scenario: Corrupt JSON file is skipped

- **WHEN** the application starts and one job file contains invalid JSON
- **THEN** a warning is logged for the corrupt file
- **AND** all other valid job files are loaded successfully

### Requirement: Job ID is deterministic

The system SHALL generate one-time task IDs as `one_time_<16hex>` where the hex string is derived from a SHA256 hash of `{fires_at, task, room_id}`. Scheduling the same task with the same parameters SHALL produce the same job ID.

#### Scenario: Duplicate scheduling overwrites existing file

- **WHEN** a one-time task with identical `fires_at`, `task`, and `room_id` is scheduled twice
- **THEN** only one persisted file exists (the second write overwrites the first)
