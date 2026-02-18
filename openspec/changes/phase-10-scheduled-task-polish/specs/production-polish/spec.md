## ADDED Requirements

### Requirement: Structured logging throughout all modules
The system SHALL include `Logger` calls at appropriate levels throughout all modules:
- `Logger.info` for lifecycle events (channel started, agent created, session loaded/saved)
- `Logger.warning` for recoverable issues (config defaults used, API rate limits, retry attempts)
- `Logger.error` for failures (action crashes, LLM errors, file I/O failures)
- `Logger.debug` for detailed operational data (action params, response sizes, timing)

All log calls SHALL include relevant metadata (module name, channel, chat_id, action name) as structured fields.

#### Scenario: Channel startup is logged
- **WHEN** a CLI or Telegram channel starts successfully
- **THEN** a `Logger.info` message is emitted with the channel type and identifier

#### Scenario: Action failure is logged
- **WHEN** an action returns `{:error, reason}`
- **THEN** a `Logger.error` message is emitted with the action module name, error reason, and relevant parameters

#### Scenario: Debug logging shows action details
- **WHEN** the log level is set to `:debug` and an action executes
- **THEN** `Logger.debug` messages show the action name, input parameters, and execution time

### Requirement: Error handling in ReAct lifecycle hooks
The system SHALL wrap `on_before_cmd/2` and `on_after_cmd/3` callbacks in error handling that catches LLM timeouts, tool crashes, and malformed responses. Caught errors SHALL be logged and returned as error strings without crashing the agent process.

#### Scenario: LLM timeout in hook is caught
- **WHEN** an LLM call within a lifecycle hook exceeds the timeout
- **THEN** the error is logged, the hook returns an error tuple, and the agent remains operational for the next turn

#### Scenario: Tool crash in hook is caught
- **WHEN** a tool action raises an exception during a lifecycle hook
- **THEN** the exception is rescued, logged with stacktrace, and the agent continues operating

#### Scenario: Malformed LLM response is handled
- **WHEN** the LLM returns a response that cannot be parsed (invalid JSON, missing fields)
- **THEN** the system logs the malformed response, returns an error message to the user, and the agent remains operational

### Requirement: Graceful shutdown saves active sessions
The system SHALL trap exit signals in the Application supervisor and save all active sessions to disk before shutdown completes. The shutdown process SHALL have a configurable timeout (default 30 seconds).

#### Scenario: SIGTERM triggers session save
- **WHEN** the application receives a SIGTERM signal with active conversations
- **THEN** all active sessions are flushed to their JSONL files before the process exits

#### Scenario: Shutdown timeout is respected
- **WHEN** session saving takes longer than the shutdown timeout
- **THEN** the system logs a warning about unsaved sessions and allows the process to terminate

#### Scenario: Clean shutdown with no active sessions
- **WHEN** the application receives a SIGTERM with no active conversations
- **THEN** the application shuts down immediately without errors

### Requirement: Config validation at startup
The system SHALL validate configuration at startup and emit warnings for:
- Missing API keys required by enabled features (e.g., Telegram bot token when Telegram channel is enabled)
- Invalid model strings that don't match known provider patterns
- Missing workspace directory (auto-created with warning)
- Enabled channels with incomplete configuration

Validation SHALL warn but not prevent startup — the application starts in a degraded state with available features.

#### Scenario: Missing Telegram token with Telegram enabled
- **WHEN** the Telegram channel is enabled but `Application.get_env(:telegex, :token)` returns `nil`
- **THEN** a `Logger.warning` is emitted: "Telegram channel enabled but TELEGRAM_BOT_TOKEN is not set — Telegram will not start"

#### Scenario: Invalid model string
- **WHEN** the configured model string does not match a known pattern (e.g., `"gpt-5-invalid"`)
- **THEN** a `Logger.warning` is emitted with the invalid model string and a suggestion of valid formats

#### Scenario: All config valid
- **WHEN** all configuration values are valid for the enabled features
- **THEN** no validation warnings are emitted and `Logger.info` confirms "Configuration validated successfully"
