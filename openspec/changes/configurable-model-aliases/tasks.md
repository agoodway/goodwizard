## 1. Config Layer

- [ ] 1.1 Add `"models"` key to `@defaults` in `Config` with `"default" => %{"model" => "anthropic:claude-sonnet-4-5"}` structure
- [ ] 1.2 Implement `Config.model/1` that accepts a role atom and resolves via fallback chain: `[models.<role>]` → `[models.default]` → `[agent.model]` → hardcoded default
- [ ] 1.3 Implement `Config.model_base_url/1` that returns the `base_url` for a role or `nil`
- [ ] 1.4 Update `validate_model/1` to validate all model strings in the `[models]` table, not just `[agent].model`
- [ ] 1.5 Write tests for `Config.model/1` fallback chain (all four levels) and `Config.model_base_url/1`

## 2. Agent Wiring

- [ ] 2.1 Update `Goodwizard.Agent` to read model from `Config.model(:default)` at runtime in `on_before_cmd`
- [ ] 2.2 Update `Goodwizard.SubAgent` to accept model as a parameter, defaulting to `Config.model(:subagent)`
- [ ] 2.3 Update `Goodwizard.Actions.Subagent.Spawn` to pass `Config.model(:subagent)` when spawning subagents
- [ ] 2.4 Update `CronRunner` to default to `Config.model(:cron)` when no per-job model override is set
- [ ] 2.5 Update `CronLoader` to use `Config.model(:cron)` as default when loading persisted jobs without an explicit model

## 3. Config Files

- [ ] 3.1 Add commented `[models]` section to `config.toml` with `default`, `subagent`, `cron` examples and a `base_url` example
- [ ] 3.2 Update `@default_config` in `mix goodwizard.setup` with the same commented `[models]` section
- [ ] 3.3 Add `GOODWIZARD_MODEL_DEFAULT` to `@env_overrides` mapping to `["models", "default", "model"]`

## 4. Verification

- [ ] 4.1 Test backward compatibility: existing config with only `[agent].model` and no `[models]` section works unchanged
- [ ] 4.2 Test role fallback: unconfigured role falls back to `:default` then to `[agent].model`
- [ ] 4.3 Test `base_url` resolution: configured role returns URL, unconfigured returns `nil`
- [ ] 4.4 Run `mix precommit` to verify no regressions
