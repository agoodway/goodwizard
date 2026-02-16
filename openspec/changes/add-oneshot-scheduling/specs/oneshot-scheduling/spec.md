## ADDED Requirements

### Requirement: Schedule a task by delay

The system SHALL accept a `delay_minutes` parameter (positive integer), compute `delay_ms` as `delay_minutes * 60_000`, and emit a `Directive.Schedule` with the computed delay and a CronTick-compatible message payload.

#### Scenario: Delay of 20 minutes emits correct directive

- **WHEN** a user schedules a one-shot task with `delay_minutes: 20`, `task: "Send daily report"`, and `room_id: "cli:heartbeat"`
- **THEN** the system emits a `Directive.Schedule` with `delay_ms: 1_200_000` and message `%{type: "cron.task", task: "Send daily report", room_id: "cli:heartbeat"}`

#### Scenario: Zero delay is rejected

- **WHEN** a user schedules a one-shot task with `delay_minutes: 0`
- **THEN** the system returns an error indicating the delay must be a positive integer

#### Scenario: Negative delay is rejected

- **WHEN** a user schedules a one-shot task with `delay_minutes: -5`
- **THEN** the system returns an error indicating the delay must be a positive integer

### Requirement: Schedule a task by wall-clock time

The system SHALL accept an `at` parameter (ISO 8601 datetime string), compute the delta in milliseconds from the current UTC time, and emit a `Directive.Schedule` with the computed delay and a CronTick-compatible message payload. The system SHALL reject times that are in the past.

#### Scenario: Wall-clock time 30 minutes from now emits correct directive

- **WHEN** a user schedules a one-shot task with `at` set to an ISO 8601 datetime 30 minutes in the future, `task: "Send weekly summary"`, and `room_id: "telegram:main"`
- **THEN** the system emits a `Directive.Schedule` with `delay_ms` approximately equal to `1_800_000` (within reasonable clock precision) and the CronTick-compatible message payload

#### Scenario: Wall-clock time in the past is rejected

- **WHEN** a user schedules a one-shot task with `at` set to an ISO 8601 datetime that has already passed
- **THEN** the system returns an error indicating the scheduled time is in the past

#### Scenario: Invalid ISO 8601 string is rejected

- **WHEN** a user schedules a one-shot task with `at: "not-a-date"`
- **THEN** the system returns an error indicating the datetime format is invalid

### Requirement: CronTick-compatible message payload

The one-shot message payload SHALL use the format `%{type: "cron.task", task: task, room_id: room_id}`, identical to the recurring cron action's payload. This ensures the existing signal handling pipeline processes one-shot tasks without modification.

#### Scenario: One-shot task fires and is processed by signal pipeline

- **WHEN** a one-shot timer fires and delivers its message to the agent
- **THEN** the signal pipeline processes it identically to a recurring cron task, routing the task text to the specified room

### Requirement: Mutual exclusivity of scheduling modes

The action SHALL require exactly one of `delay_minutes` or `at` to be provided. Providing both or neither SHALL result in an error.

#### Scenario: Both delay_minutes and at provided

- **WHEN** a user schedules a one-shot task with both `delay_minutes: 10` and `at: "2026-02-15T15:00:00Z"`
- **THEN** the system returns an error indicating that exactly one of `delay_minutes` or `at` must be provided

#### Scenario: Neither delay_minutes nor at provided

- **WHEN** a user schedules a one-shot task with only `task` and `room_id` but no `delay_minutes` or `at`
- **THEN** the system returns an error indicating that exactly one of `delay_minutes` or `at` must be provided

### Requirement: Action registered in agent tools list

The `Goodwizard.Actions.Scheduling.OneShot` action SHALL be registered in the `Goodwizard.Agent` tools list alongside the existing `Goodwizard.Actions.Scheduling.Cron` action.

#### Scenario: Agent starts with one-shot action available

- **WHEN** the Goodwizard agent starts
- **THEN** the `schedule_oneshot_task` tool is available in the agent's tool list and can be invoked by the LLM
