## ADDED Requirements

### Requirement: Configurable CLI session retention limit

The system SHALL support a `session.max_cli_sessions` configuration option that controls the maximum number of CLI session files to retain. The default value SHALL be `50`.

#### Scenario: Config option is set

- **WHEN** `config.toml` contains `[session]` with `max_cli_sessions = 20`
- **THEN** the system SHALL retain at most 20 CLI session files

#### Scenario: Config option is not set

- **WHEN** `config.toml` does not contain `session.max_cli_sessions`
- **THEN** the system SHALL use the default value of `50`

### Requirement: Old CLI sessions are cleaned up on CLI start

The CLI server SHALL clean up old CLI session files when it initializes. It SHALL list all files matching the pattern `cli-direct-*.jsonl` in the sessions directory, sort them by modification time (newest first), and delete any files beyond the configured retention limit.

#### Scenario: Fewer sessions than limit

- **WHEN** the sessions directory contains 10 CLI session files and `max_cli_sessions` is 50
- **THEN** no files SHALL be deleted

#### Scenario: More sessions than limit

- **WHEN** the sessions directory contains 60 CLI session files and `max_cli_sessions` is 50
- **THEN** the 10 oldest CLI session files (by mtime) SHALL be deleted

#### Scenario: Non-CLI session files are not affected

- **WHEN** the sessions directory contains `telegram-12345.jsonl` and `cli-direct-*.jsonl` files
- **THEN** cleanup SHALL only consider `cli-direct-*.jsonl` files; Telegram session files SHALL NOT be deleted

### Requirement: Cleanup handles filesystem errors gracefully

The cleanup process SHALL log warnings for any files it fails to delete and SHALL NOT crash or prevent the CLI server from starting.

#### Scenario: File deletion fails

- **WHEN** a session file cannot be deleted due to permissions
- **THEN** the system SHALL log a warning and continue with the remaining files
