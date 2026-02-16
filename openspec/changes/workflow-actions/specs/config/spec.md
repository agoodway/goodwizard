## MODIFIED Requirements

### Requirement: Config includes workflow section

The `Goodwizard.Config` module SHALL include a `[workflow]` section with default values: `enabled` (boolean, default `false`), `default_timeout_ms` (integer, default `20000`), `max_stdout_bytes` (integer, default `512000`), `state_ttl_minutes` (integer, default `60`).

#### Scenario: Workflow config defaults are set

- **WHEN** no `[workflow]` section exists in config.toml
- **THEN** `Config.get(["workflow", "enabled"])` returns `false` and other workflow keys return their defaults

#### Scenario: Workflow config can be overridden via TOML

- **WHEN** config.toml contains `[workflow]` with `enabled = true` and `default_timeout_ms = 30000`
- **THEN** `Config.get(["workflow", "enabled"])` returns `true` and `Config.get(["workflow", "default_timeout_ms"])` returns `30000`
