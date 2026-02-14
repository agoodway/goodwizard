## ADDED Requirements

### Requirement: Heartbeat reads HEARTBEAT.md on a schedule
The system SHALL provide a `Goodwizard.Heartbeat` GenServer that periodically reads `HEARTBEAT.md` from the workspace directory and processes its contents as a message through the agent pipeline. The heartbeat interval SHALL be configurable via `config.toml` with a default of 5 minutes.

#### Scenario: Heartbeat processes file on schedule
- **WHEN** the heartbeat timer fires and `HEARTBEAT.md` exists in the workspace
- **THEN** the system reads the file contents and sends them as a message to the agent for processing

#### Scenario: Heartbeat skips when file is missing
- **WHEN** the heartbeat timer fires and `HEARTBEAT.md` does not exist in the workspace
- **THEN** the system logs a debug message and takes no further action until the next tick

#### Scenario: Heartbeat skips when file is unchanged
- **WHEN** the heartbeat timer fires and `HEARTBEAT.md` has not been modified since the last read
- **THEN** the system skips processing and waits for the next tick

### Requirement: Heartbeat is started under Application supervisor
The system SHALL start the Heartbeat GenServer under the Application supervisor when heartbeat is enabled in configuration. The heartbeat process SHALL be supervised with a `:permanent` restart strategy.

#### Scenario: Heartbeat starts when enabled
- **WHEN** the application starts with `heartbeat.enabled = true` in config
- **THEN** the Heartbeat GenServer is started as a child of the Application supervisor

#### Scenario: Heartbeat does not start when disabled
- **WHEN** the application starts with `heartbeat.enabled = false` or no heartbeat config
- **THEN** no Heartbeat GenServer is started

### Requirement: Heartbeat targets a configurable Messaging room
The system SHALL route heartbeat messages to a configurable Messaging room via `Goodwizard.Messaging`. The room is resolved via `get_or_create_room_by_external_binding`.

#### Scenario: Heartbeat routes to configured room
- **WHEN** heartbeat config specifies a room binding (e.g., `channel = "telegram"`, `chat_id = "12345"`)
- **THEN** heartbeat messages are saved to the Messaging room bound to `{:telegram, bot, "12345"}` and processed through an agent targeting that room

#### Scenario: Heartbeat uses default room when not configured
- **WHEN** heartbeat config does not specify channel or chat_id
- **THEN** heartbeat messages are saved to a Messaging room bound to `{:cli, "goodwizard", "heartbeat"}` and processed through an agent targeting that room
