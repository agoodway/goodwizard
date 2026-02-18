## ADDED Requirements

### Requirement: Scheduled task action accepts schedule parameters
The system SHALL provide a `Goodwizard.Actions.Scheduling.ScheduledTask` action that accepts a cron expression, task description, and target room_id. The action SHALL validate the cron expression format and return a `Directive.Schedule` for Jido's scheduler to pick up.

Schema fields:
- `schedule` (string, required) — cron expression (e.g., `"0 9 * * *"`)
- `task` (string, required) — description of the task to execute
- `room_id` (string, required) — target Messaging room identifier

#### Scenario: Valid cron schedule creates directive
- **WHEN** the Scheduled task action is called with schedule `"0 9 * * *"`, task `"check email"`, and room_id `"room_abc123"`
- **THEN** the action returns `{:ok, %{directive: %Directive.Schedule{...}}}` with the cron expression, task, and room_id encoded in the directive

#### Scenario: Invalid cron expression returns error
- **WHEN** the Scheduled task action is called with schedule `"not-a-cron"`
- **THEN** the action returns `{:error, "Invalid cron expression: not-a-cron"}`

#### Scenario: Missing required fields returns error
- **WHEN** the Scheduled task action is called without a room_id field
- **THEN** the action returns a schema validation error indicating the required field is missing

### Requirement: Scheduled task action is registered as an agent tool
The system SHALL register `Goodwizard.Actions.Scheduling.ScheduledTask` in the agent's tool registry so the LLM can invoke it during conversations. The tool description SHALL clearly explain the cron expression format and required parameters.

#### Scenario: Agent can discover cron tool
- **WHEN** the agent lists available tools
- **THEN** the scheduled task scheduling tool appears with its name, description, and parameter schema

#### Scenario: Agent schedules a recurring task via conversation
- **WHEN** a user says "remind me to check logs every morning at 9am"
- **THEN** the agent calls the Scheduled task action with an appropriate cron expression and the current room_id
