## ADDED Requirements

### Requirement: Mode parameter
The `schedule_scheduled_task` action SHALL accept an optional `mode` parameter with allowed values `"isolated"` or `"main"`. The default value SHALL be `"isolated"`.

#### Scenario: Mode defaults to isolated
- **WHEN** the Scheduled task action is called without a `mode` parameter
- **THEN** the action SHALL schedule the task with `mode: "isolated"` in the message payload

#### Scenario: Mode set to isolated
- **WHEN** the Scheduled task action is called with `mode: "isolated"`
- **THEN** the action SHALL include `mode: "isolated"` in the cron message payload

#### Scenario: Invalid mode value rejected
- **WHEN** the Scheduled task action is called with `mode: "invalid_value"`
- **THEN** the action SHALL return a schema validation error

### Requirement: Model parameter
The `schedule_scheduled_task` action SHALL accept an optional `model` parameter as a string. The parameter SHALL only be included in the cron message payload when `mode` is `"isolated"`.

#### Scenario: Model included in isolated mode
- **WHEN** the Scheduled task action is called with `mode: "isolated"` and `model: "anthropic:claude-haiku-4-5"`
- **THEN** the cron message payload SHALL include `model: "anthropic:claude-haiku-4-5"`

#### Scenario: Model omitted in main mode
- **WHEN** the Scheduled task action is called with `mode: "main"` and `model: "anthropic:claude-haiku-4-5"`
- **THEN** the cron message payload SHALL NOT include the `model` field

#### Scenario: No model specified
- **WHEN** the Scheduled task action is called without a `model` parameter
- **THEN** the cron message payload SHALL NOT include the `model` field

### Requirement: Backwards compatibility
Existing calls to `schedule_scheduled_task` without `mode` or `model` parameters SHALL now default to isolated mode. To preserve the legacy inline behavior, callers MUST explicitly pass `mode: "main"`.

#### Scenario: Existing usage defaults to isolated
- **WHEN** the Scheduled task action is called with only `schedule`, `task`, and `room_id`
- **THEN** the action SHALL schedule the task with `mode: "isolated"` and return `{:ok, %{scheduled: true, ...}, [directive]}`
