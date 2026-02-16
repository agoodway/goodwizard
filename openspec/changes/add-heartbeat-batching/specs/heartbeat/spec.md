## ADDED Requirements

### Requirement: Structured format support
The heartbeat GenServer SHALL detect and handle markdown task-list format in HEARTBEAT.md, in addition to plain text. Detection and parsing are delegated to `Goodwizard.Heartbeat.Parser`.

#### Scenario: Task-list format detected
- **GIVEN** a HEARTBEAT.md file containing one or more lines matching `- [ ] <text>` or `- [x] <text>`
- **WHEN** the heartbeat reads and processes the file
- **THEN** the system SHALL delegate to the parser for check extraction
- **AND** dispatch the result as a structured numbered prompt via `dispatch_heartbeat/2`
- **AND** include `checks` metadata in the saved Messaging payload

#### Scenario: Plain text format detected
- **GIVEN** a HEARTBEAT.md file containing no task-list syntax
- **WHEN** the heartbeat reads and processes the file
- **THEN** the system SHALL use the existing single-blob dispatch path
- **AND** the behavior SHALL be identical to the pre-change heartbeat implementation
