### Requirement: Scoped log capture

The system SHALL capture only log entries produced during the scenario run.

#### Scenario: Logger handler installed during run
- **WHEN** the scenario runner starts execution
- **THEN** it SHALL install a custom Erlang `:logger` handler that buffers events to an Agent process

#### Scenario: Logger handler removed after run
- **WHEN** the scenario run completes (success or failure)
- **THEN** the custom `:logger` handler SHALL be removed in a `try/after` block

#### Scenario: Log entries include structured metadata
- **WHEN** a log event is captured
- **THEN** the stored entry SHALL include level, message text, timestamp, and source module

### Requirement: Tool call telemetry capture

The system SHALL capture tool execution events via telemetry.

#### Scenario: Telemetry attachment
- **WHEN** the scenario runner starts
- **THEN** it SHALL attach to `[:jido, :ai, :strategy, :react, :start]`, `[:jido, :ai, :strategy, :react, :complete]`, and `[:jido, :ai, :strategy, :react, :failed]` events, as well as `[:jido, :ai, :request, :start]`, `[:jido, :ai, :request, :complete]`, and `[:jido, :ai, :request, :failed]` events

#### Scenario: Tool call data
- **WHEN** a tool call completes during the scenario
- **THEN** the captured data SHALL include tool name, result status, and duration in milliseconds
