## ADDED Requirements

### Requirement: Isolated mode execution
WHEN `mode` is `"isolated"`, the system SHALL spawn a child agent via the SubAgent pattern on each cron tick, send the task as the child agent's query, and save the response to the target Messaging room.

#### Scenario: Isolated cron tick spawns child agent
- **WHEN** a cron tick fires with `mode: "isolated"`, `task: "generate daily report"`, and `room_id: "room_abc123"`
- **THEN** the signal handler SHALL spawn a child agent, send `"generate daily report"` as its query, and save the agent's response to room `"room_abc123"`

#### Scenario: Child agent completes and is cleaned up
- **WHEN** a child agent spawned by an isolated cron tick finishes processing
- **THEN** the child agent process SHALL be stopped and its resources released, regardless of whether the task succeeded or failed

#### Scenario: Child agent failure saves error to room
- **WHEN** a child agent spawned by an isolated cron tick encounters an error (timeout, LLM failure, tool crash)
- **THEN** an error message SHALL be saved to the target Messaging room indicating the scheduled task failed

#### Scenario: Child agent has no access to main conversation context
- **WHEN** a child agent is spawned for an isolated cron tick
- **THEN** the child agent SHALL NOT have access to the main agent's conversation history, session state, or in-flight context

### Requirement: Model override in isolated mode
WHEN `mode` is `"isolated"` and a `model` parameter is provided, the child agent SHALL use the specified model instead of the default model.

#### Scenario: Custom model specified
- **WHEN** a cron tick fires with `mode: "isolated"` and `model: "anthropic:claude-haiku-4-5"`
- **THEN** the child agent SHALL be configured with `model: "anthropic:claude-haiku-4-5"`

#### Scenario: No model specified in isolated mode
- **WHEN** a cron tick fires with `mode: "isolated"` and no `model` is provided
- **THEN** the child agent SHALL use the default model (`"anthropic:claude-sonnet-4-5"`)

### Requirement: Model parameter ignored in main mode
WHEN `mode` is `"main"` (or mode is not specified), the `model` parameter SHALL be ignored and cron execution SHALL follow the existing inline dispatch behavior.

#### Scenario: Main mode with model set
- **WHEN** a cron tick fires with `mode: "main"` and `model: "anthropic:claude-haiku-4-5"`
- **THEN** the task SHALL execute through the main agent's pipeline and the `model` parameter SHALL be ignored

#### Scenario: Default mode is isolated
- **WHEN** a cron tick fires without a `mode` field in the message payload
- **THEN** the task SHALL execute in isolated mode, spawning a child agent

### Requirement: Concurrency control for isolated agents
The system SHALL enforce a maximum number of concurrent isolated scheduled-task agents to prevent resource exhaustion.

#### Scenario: Concurrent limit not reached
- **WHEN** an isolated cron tick fires and the number of active isolated agents is below the limit
- **THEN** a new child agent SHALL be spawned normally

#### Scenario: Concurrent limit reached
- **WHEN** an isolated cron tick fires and the number of active isolated agents is at the limit
- **THEN** the tick SHALL be skipped and an error message SHALL be saved to the target Messaging room
