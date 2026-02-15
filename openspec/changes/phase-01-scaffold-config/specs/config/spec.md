## ADDED Requirements

### Requirement: Config loads from TOML file
The system SHALL load configuration from `config.toml (project root)` at startup. The TOML file structure SHALL support sections: `[agent]`, `[channels.cli]`, `[channels.telegram]`, `[tools.exec]`, `[tools]`, `[browser]`, and `[browser.search]`.

#### Scenario: Config file exists with valid TOML
- **WHEN** `config.toml (project root)` exists and contains valid TOML
- **THEN** all values from the file SHALL be loaded into the Config GenServer state

#### Scenario: Config file does not exist
- **WHEN** `config.toml (project root)` does not exist
- **THEN** the system SHALL start with hardcoded default values and log a warning

#### Scenario: Config file contains invalid TOML
- **WHEN** the config file contains malformed TOML
- **THEN** the system SHALL start with defaults and log an error with the parse failure reason

### Requirement: Config provides default values
The system SHALL use the following defaults when no TOML file is present or a key is missing:
- `agent.workspace` = `"priv/workspace"`
- `agent.model` = `"anthropic:claude-sonnet-4-5"`
- `agent.max_tokens` = `8192`
- `agent.temperature` = `0.7`
- `agent.max_tool_iterations` = `20`
- `agent.memory_window` = `50`
- `channels.cli.enabled` = `true`
- `channels.telegram.enabled` = `false`
- `channels.telegram.allow_from` = `[]`
- `tools.exec.timeout` = `60`
- `tools.restrict_to_workspace` = `false`
- `browser.headless` = `true`
- `browser.adapter` = `"vibium"`
- `browser.timeout` = `30000`
- `browser.search.brave_api_key` = `""`

#### Scenario: No config file uses all defaults
- **WHEN** no config file exists
- **THEN** `Config.get()` SHALL return a map containing all default values listed above

#### Scenario: Partial config file merges with defaults
- **WHEN** config file sets only `[agent] model = "openai:gpt-4o"`
- **THEN** `Config.get()` SHALL return the overridden model value with all other keys at their defaults

### Requirement: Environment variables override TOML values
The system SHALL allow environment variables to override TOML values with higher priority. The mapping SHALL be:
- `BRAVE_API_KEY` → `browser.search.brave_api_key`
- `GOODWIZARD_WORKSPACE` → `agent.workspace`
- `GOODWIZARD_MODEL` → `agent.model`

Note: `TELEGRAM_BOT_TOKEN` is NOT managed by `Goodwizard.Config`. It wires directly to `config :telegex, token:` in `runtime.exs` and is read by Telegex at runtime.

#### Scenario: Env var overrides TOML value
- **WHEN** TOML sets `agent.model = "anthropic:claude-sonnet-4-5"` and `GOODWIZARD_MODEL=openai:gpt-4o` is set
- **THEN** `Config.get([:agent, :model])` SHALL return `"openai:gpt-4o"`

#### Scenario: Env var overrides default when no TOML
- **WHEN** no config file exists and `GOODWIZARD_WORKSPACE=/tmp/work` is set
- **THEN** `Config.get([:agent, :workspace])` SHALL return `"/tmp/work"`

#### Scenario: Unset env var does not override
- **WHEN** `GOODWIZARD_MODEL` is not set in the environment
- **THEN** the TOML value or default SHALL be used for `agent.model`

#### Scenario: BRAVE_API_KEY env var overrides browser config
- **WHEN** `BRAVE_API_KEY=my-brave-key` is set in the environment
- **THEN** `Config.get([:browser, :search, :brave_api_key])` SHALL return `"my-brave-key"`

### Requirement: Telegex caller adapter configured in config.exs
The system SHALL configure the Telegex caller adapter in `config.exs` as a compile-time setting: `config :telegex, caller_adapter: {Telegex.Caller.FinchAdapter, [receive_timeout: 60_000]}`.

#### Scenario: Telegex adapter is configured at compile time
- **WHEN** the project compiles
- **THEN** `Application.get_env(:telegex, :caller_adapter)` SHALL return `{Telegex.Caller.FinchAdapter, [receive_timeout: 60_000]}`

### Requirement: Telegram bot token configured in runtime.exs
The system SHALL wire `TELEGRAM_BOT_TOKEN` to Telegex in `runtime.exs`: `config :telegex, token: System.get_env("TELEGRAM_BOT_TOKEN")`.

#### Scenario: TELEGRAM_BOT_TOKEN env var wires to Telegex
- **WHEN** `TELEGRAM_BOT_TOKEN=abc123` is set in the environment and the application starts
- **THEN** `Application.get_env(:telegex, :token)` SHALL return `"abc123"`

#### Scenario: Missing TELEGRAM_BOT_TOKEN
- **WHEN** `TELEGRAM_BOT_TOKEN` is not set in the environment
- **THEN** `Application.get_env(:telegex, :token)` SHALL return `nil`

### Requirement: Browser config wired to jido_browser application env
On application startup, `Goodwizard.Config` SHALL write browser settings to the `:jido_browser` application config.

#### Scenario: Brave API key wired to jido_browser
- **WHEN** `Config.get([:browser, :search, :brave_api_key])` returns `"my-key"`
- **THEN** `Application.get_env(:jido_browser, :brave_search_api_key)` SHALL return `"my-key"`

#### Scenario: Adapter config wired to jido_browser
- **WHEN** `Config.get([:browser, :adapter])` returns `"vibium"`
- **THEN** the application config SHALL map `"vibium"` to `JidoBrowser.Adapters.Vibium`

### Requirement: Config API provides accessor functions
The Config module SHALL expose the following public API:
- `get/0` — returns the entire config map
- `get/1` — accepts a key path (list of atoms) and returns the nested value
- `workspace/0` — returns the expanded workspace path
- `memory_dir/0` — returns the expanded memory directory path (`workspace/memory`)
- `sessions_dir/0` — returns the expanded sessions directory path (`workspace/sessions`)
- `model/0` — returns the current model string

#### Scenario: get/0 returns full config
- **WHEN** `Config.get()` is called
- **THEN** it SHALL return the complete merged configuration as a nested map

#### Scenario: get/1 with key path
- **WHEN** `Config.get([:agent, :model])` is called
- **THEN** it SHALL return the value at that path or `nil` if not found

#### Scenario: workspace/0 expands relative path
- **WHEN** config has `agent.workspace = "priv/workspace"` and `Config.workspace()` is called
- **THEN** it SHALL return the fully expanded absolute path (e.g., `"/path/to/project/priv/workspace"`)

#### Scenario: model/0 returns model string
- **WHEN** `Config.model()` is called
- **THEN** it SHALL return the configured model string (e.g., `"anthropic:claude-sonnet-4-5"`)

### Requirement: Workspace directory creation
The system SHALL ensure the workspace directory and its subdirectories (`memory/`, `sessions/`) exist after config initialization.

#### Scenario: Workspace directory does not exist
- **WHEN** the configured workspace path does not exist at startup
- **THEN** the system SHALL create the workspace directory, `memory/`, and `sessions/` subdirectories during Config init

#### Scenario: Workspace directory already exists
- **WHEN** the configured workspace path already exists
- **THEN** the system SHALL ensure `memory/` and `sessions/` subdirectories exist without error
