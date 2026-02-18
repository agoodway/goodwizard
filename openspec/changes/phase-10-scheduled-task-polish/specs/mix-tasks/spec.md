## ADDED Requirements

### Requirement: mix goodwizard.start launches all enabled channels
The system SHALL provide a `mix goodwizard.start` task that starts the full Goodwizard application with all channels enabled in configuration. The task SHALL block until the process is terminated (via SIGTERM or Ctrl+C).

#### Scenario: Start with CLI and Telegram enabled
- **WHEN** `mix goodwizard.start` is run with both CLI and Telegram channels enabled in config
- **THEN** the application starts, both channels begin accepting input, and the process blocks until interrupted

#### Scenario: Start with only CLI enabled
- **WHEN** `mix goodwizard.start` is run with only the CLI channel enabled
- **THEN** the application starts with just the CLI channel and the process blocks until interrupted

#### Scenario: Start with missing config file
- **WHEN** `mix goodwizard.start` is run and no config.toml exists
- **THEN** the application starts with default configuration and logs a warning about using defaults

### Requirement: mix goodwizard.status shows system state
The system SHALL provide a `mix goodwizard.status` task that displays the current system configuration and runtime state. The output SHALL include:
- Configuration source and key settings (model, workspace path)
- Active rooms and messages from `Goodwizard.Messaging`
- Channel instances from InstanceServer
- Memory stats (long-term memory size, history entry count)

#### Scenario: Status with running system
- **WHEN** `mix goodwizard.status` is run while Goodwizard is running with active conversations
- **THEN** the output shows config settings, lists active channels as "connected", shows conversation IDs, and reports memory file sizes

#### Scenario: Status with no active conversations
- **WHEN** `mix goodwizard.status` is run while Goodwizard is running with no active conversations
- **THEN** the output shows config settings, lists active channels, and reports "No active conversations"

#### Scenario: Status when application is not running
- **WHEN** `mix goodwizard.status` is run and the application is not started
- **THEN** the task starts the application, gathers status, prints it, and exits cleanly
