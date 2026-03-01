## ADDED Requirements

### Requirement: Log directory is configurable via TOML

The system SHALL read the log directory from the `[logging] dir` key in `config.toml`. The value SHALL be a filesystem path (relative or absolute). Relative paths SHALL be expanded relative to the project root (`File.cwd!()`).

#### Scenario: Custom log directory via TOML
- **WHEN** `config.toml` contains `[logging]` with `dir = "/var/log/goodwizard"`
- **THEN** log files SHALL be written to `/var/log/goodwizard/<env>.log`

#### Scenario: Relative path in TOML
- **WHEN** `config.toml` contains `[logging]` with `dir = "tmp/logs"`
- **THEN** log files SHALL be written to `<cwd>/tmp/logs/<env>.log`

### Requirement: Log directory is configurable via environment variable

The system SHALL read the `GOODWIZARD_LOG_DIR` environment variable as an override for the log directory. The env var SHALL take priority over the TOML value. When backends are configured, the env var SHALL override the `dir` of the first file-type backend.

#### Scenario: Env var overrides TOML
- **WHEN** `GOODWIZARD_LOG_DIR` is set to `/tmp/gw-logs` AND `config.toml` contains `dir = "logs"`
- **THEN** log files SHALL be written to `/tmp/gw-logs/<env>.log`

#### Scenario: Env var alone
- **WHEN** `GOODWIZARD_LOG_DIR` is set to `/tmp/gw-logs` AND no `[logging]` section exists in TOML
- **THEN** log files SHALL be written to `/tmp/gw-logs/<env>.log`

### Requirement: Default log directory is preserved

The system SHALL default to `logs/` relative to the project root when neither the TOML key nor the env var is set and no backends are configured.

#### Scenario: No configuration provided
- **WHEN** no `[logging]` section exists in `config.toml` AND `GOODWIZARD_LOG_DIR` is not set
- **THEN** log files SHALL be written to `<cwd>/logs/<env>.log`

### Requirement: Log directory is created automatically

The system SHALL create the configured log directory (and parent directories) if it does not exist, before writing log files. This applies to each file-type backend independently.

#### Scenario: Directory does not exist
- **WHEN** the configured log directory does not exist
- **THEN** the system SHALL create it (including parents) before adding the logger handler

### Requirement: Config accessor for log directory

The system SHALL expose a `Goodwizard.Config.log_dir/0` function that returns the expanded absolute path to the first agent-visible file backend's directory.

#### Scenario: Runtime access to log directory
- **WHEN** a module calls `Goodwizard.Config.log_dir()` and at least one agent-visible file backend exists
- **THEN** it SHALL return the expanded absolute path of the first agent-visible file backend's log directory

#### Scenario: No agent-visible file backend
- **WHEN** a module calls `Goodwizard.Config.log_dir()` and no agent-visible file backend is configured
- **THEN** it SHALL return `nil`

### Requirement: Multiple log backends

The system SHALL support a `[[logging.backends]]` TOML array-of-tables, where each entry configures a log destination. All configured backends SHALL receive every log event.

#### Scenario: Two file backends
- **WHEN** `config.toml` contains two `[[logging.backends]]` entries with `type = "file"` and different `dir` values
- **THEN** log files SHALL be written to both directories simultaneously

#### Scenario: File and webhook backends
- **WHEN** `config.toml` contains one `[[logging.backends]]` with `type = "file"` and one with `type = "webhook"`
- **THEN** log events SHALL be written to the file AND posted to the webhook URL

#### Scenario: Backends configured but no file backend
- **WHEN** `GOODWIZARD_LOG_DIR` is set and `[[logging.backends]]` contains only webhook/custom entries
- **THEN** the env var SHALL be ignored
- **AND** startup SHALL emit a warning that no file backend exists to apply the override

### Requirement: Backend behaviour

The system SHALL define a `Goodwizard.Logging.Backend` behaviour with:
- `init(config)` — receives the backend's config map, returns `{:ok, state}` or `{:error, reason}`
- `log(state, event)` — receives the backend state and an Erlang logger event, returns `:ok`

#### Scenario: Custom backend module
- **WHEN** a `[[logging.backends]]` entry contains `type = "custom"` and `module = "MyApp.SyslogBackend"`
- **THEN** the system SHALL call `MyApp.SyslogBackend.init/1` at startup and `MyApp.SyslogBackend.log/2` for each event

#### Scenario: Custom backend module is invalid
- **WHEN** a `[[logging.backends]]` entry contains `type = "custom"` but the module is missing, not loadable, or does not implement required callbacks
- **THEN** startup SHALL skip that backend entry
- **AND** startup SHALL log a warning
- **AND** healthy backends SHALL continue operating

### Requirement: Built-in file backend

The system SHALL ship a `Goodwizard.Logging.Backends.File` module implementing the backend behaviour. It SHALL write log events to `<dir>/<env>.log` directly from `log/2`.

#### Scenario: File backend writes logs
- **WHEN** a file backend is configured with `dir = "/var/log/gw"`
- **THEN** log events SHALL be appended to `/var/log/gw/<env>.log`

### Requirement: Built-in webhook backend

The system SHALL ship a `Goodwizard.Logging.Backends.Webhook` module implementing the backend behaviour. It SHALL POST formatted log events to the configured URL using `Req`. Delivery is fire-and-forget — failures SHALL be logged to other backends but SHALL NOT block or crash the system.

#### Scenario: Webhook backend posts logs
- **WHEN** a webhook backend is configured with `url = "https://logs.example.com/ingest"`
- **THEN** log events SHALL be HTTP POSTed to that URL as JSON

#### Scenario: Webhook endpoint is unreachable
- **WHEN** the webhook endpoint returns an error or is unreachable
- **THEN** the system SHALL log a warning via other backends and continue operating

### Requirement: Agent-visible flag

Each backend configuration SHALL support an `agent_visible` boolean. The default SHALL be `true` for file backends and `false` for webhook/custom backends. Only agent-visible backends SHALL be exposed to agent actions (dev-log skill, self-debugging tools).

#### Scenario: Agent reads only visible logs
- **WHEN** two file backends are configured, one with `agent_visible = true` and one with `agent_visible = false`
- **THEN** the dev-log skill SHALL only read from the agent-visible backend's directory

#### Scenario: Default agent visibility
- **WHEN** a file backend is configured without an explicit `agent_visible` key
- **THEN** it SHALL default to `agent_visible = true`

#### Scenario: Webhook default visibility
- **WHEN** a webhook backend is configured without an explicit `agent_visible` key
- **THEN** it SHALL default to `agent_visible = false`

### Requirement: Backend error isolation

If a backend raises an exception in `log/2`, the dispatcher SHALL catch the error, log a warning to the remaining healthy backends, and continue delivering events to all other backends. A failing backend SHALL NOT crash the logger or affect other backends.

#### Scenario: One backend crashes
- **WHEN** backend A raises an exception during `log/2`
- **THEN** backend B SHALL continue receiving log events normally
- **AND** a warning about backend A's failure SHALL be logged to backend B

#### Scenario: Repeated backend failure warning throttling
- **WHEN** a backend keeps failing on every `log/2` call
- **THEN** the dispatcher SHALL throttle warnings to avoid warning floods (at minimum, one warning per backend until recovery)

### Requirement: Dispatcher as single logger handler

The system SHALL register a single `Goodwizard.Logging.Dispatcher` module as an Erlang `:logger` handler. The dispatcher SHALL fan out each log event to all configured backends.

#### Scenario: Single handler registration
- **WHEN** three backends are configured
- **THEN** only one Erlang logger handler (`Goodwizard.Logging.Dispatcher`) SHALL be registered (not three)
