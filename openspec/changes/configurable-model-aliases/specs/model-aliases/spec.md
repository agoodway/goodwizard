## ADDED Requirements

### Requirement: Model roles are configurable via TOML
The system SHALL support a `[models.<role>]` table in `config.toml` where each role defines a `model` string and an optional `base_url` string.

#### Scenario: Single default model configured
- **WHEN** `config.toml` contains `[models.default]` with `model = "anthropic:claude-sonnet-4-5"`
- **THEN** `Config.model(:default)` SHALL return `"anthropic:claude-sonnet-4-5"`

#### Scenario: Multiple roles configured
- **WHEN** `config.toml` contains `[models.default]` with `model = "anthropic:claude-sonnet-4-5"` and `[models.subagent]` with `model = "anthropic:claude-haiku-4-5"`
- **THEN** `Config.model(:default)` SHALL return `"anthropic:claude-sonnet-4-5"` and `Config.model(:subagent)` SHALL return `"anthropic:claude-haiku-4-5"`

#### Scenario: Role with base_url
- **WHEN** `config.toml` contains `[models.moonshot]` with `model = "openai:moonshot-v1-128k"` and `base_url = "https://api.moonshot.ai/v1"`
- **THEN** `Config.model(:moonshot)` SHALL return `"openai:moonshot-v1-128k"` and `Config.model_base_url(:moonshot)` SHALL return `"https://api.moonshot.ai/v1"`

### Requirement: Model resolution follows a fallback chain
The system SHALL resolve `Config.model(role)` using this precedence: (1) `[models.<role>].model`, (2) `[models.default].model`, (3) `[agent].model`, (4) hardcoded default.

#### Scenario: Role not configured falls back to default role
- **WHEN** `config.toml` defines `[models.default]` but no `[models.subagent]`
- **THEN** `Config.model(:subagent)` SHALL return the value from `[models.default].model`

#### Scenario: No models table falls back to agent.model
- **WHEN** `config.toml` has no `[models]` section but has `[agent]` with `model = "openai:gpt-4"`
- **THEN** `Config.model(:default)` SHALL return `"openai:gpt-4"`

#### Scenario: Empty config falls back to hardcoded default
- **WHEN** `config.toml` has no `[models]` section and no `[agent].model`
- **THEN** `Config.model(:default)` SHALL return the hardcoded default model string

### Requirement: base_url returns nil when not configured
The system SHALL return `nil` from `Config.model_base_url(role)` when no `base_url` is set for that role or its fallback chain.

#### Scenario: Role without base_url
- **WHEN** `[models.default]` has `model` but no `base_url`
- **THEN** `Config.model_base_url(:default)` SHALL return `nil`

#### Scenario: Unknown role without base_url
- **WHEN** no `[models.scheduled_tasks]` exists and `[models.default]` has no `base_url`
- **THEN** `Config.model_base_url(:scheduled_tasks)` SHALL return `nil`

### Requirement: Agent uses configured default model
The primary `Goodwizard.Agent` SHALL use `Config.model(:default)` to determine its LLM model at runtime.

#### Scenario: Agent reads model from config
- **WHEN** `config.toml` sets `[models.default].model = "google:gemini-pro"`
- **THEN** the Agent's LLM calls SHALL use `"google:gemini-pro"`

### Requirement: SubAgent uses configured subagent model
`Goodwizard.SubAgent` SHALL use `Config.model(:subagent)` to determine its LLM model when spawned.

#### Scenario: SubAgent uses subagent role
- **WHEN** `config.toml` sets `[models.subagent].model = "anthropic:claude-haiku-4-5"`
- **THEN** spawned subagents SHALL use `"anthropic:claude-haiku-4-5"`

#### Scenario: SubAgent falls back to default when subagent role not configured
- **WHEN** no `[models.subagent]` exists in `config.toml`
- **THEN** spawned subagents SHALL use the model resolved by `Config.model(:subagent)` (which falls back to `:default`)

### Requirement: ScheduledTaskRunner uses configured cron model
`Goodwizard.Actions.Scheduling.ScheduledTaskRunner` SHALL default to `Config.model(:scheduled_tasks)` when no per-job model override is specified.

#### Scenario: Scheduled task without model override
- **WHEN** a scheduled task is executed without an explicit `:model` option
- **THEN** the cron runner SHALL use `Config.model(:scheduled_tasks)`

#### Scenario: Scheduled task with explicit model override
- **WHEN** a scheduled task specifies `model: "openai:gpt-4"`
- **THEN** the cron runner SHALL use `"openai:gpt-4"` regardless of config

### Requirement: Backward compatibility with agent.model
Existing configurations using only `[agent].model` SHALL continue to work without changes. The `[agent].model` value SHALL be used as a fallback when no `[models]` section is present.

#### Scenario: Legacy config with only agent.model
- **WHEN** `config.toml` has `[agent].model = "anthropic:claude-sonnet-4-5"` and no `[models]` section
- **THEN** all model resolution calls SHALL return `"anthropic:claude-sonnet-4-5"`

### Requirement: Setup task generates models config
`mix goodwizard.setup` SHALL include a commented-out `[models]` section in the generated `config.toml` template showing available roles and their defaults.

#### Scenario: Fresh setup includes models template
- **WHEN** `mix goodwizard.setup` generates a new `config.toml`
- **THEN** the file SHALL contain commented `[models.default]`, `[models.subagent]`, and `[models.scheduled_tasks]` examples

### Requirement: Model validation accepts known provider prefixes
The system SHALL validate model strings against known provider prefixes and emit a warning for unrecognized prefixes. The known prefixes SHALL include `anthropic:`, `openai:`, `google:`, `ollama:`, and `mistral:`.

#### Scenario: Valid model prefix
- **WHEN** `[models.default].model = "openai:gpt-4"`
- **THEN** no validation warning SHALL be emitted

#### Scenario: Unknown model prefix
- **WHEN** `[models.default].model = "unknown:some-model"`
- **THEN** a warning SHALL be logged but the system SHALL continue to start
