## Why

LLM model strings are hardcoded in three places (`Agent`, `SubAgent`, `config.ex` defaults) and only the primary agent model is configurable via `config.toml`. There's no way to configure which model subagents or cron runners use, and no way to point at alternative providers (e.g. Moonshot, Ollama, vLLM) with custom base URLs without code changes. Exposing model aliases and provider base URLs in `config.toml` makes the system provider-agnostic and lets operators tune cost/performance per role without redeploying.

## What Changes

- Add a `[models]` table to `config.toml` that defines named model aliases (e.g. `default`, `fast`, `reasoning`, `subagent`, `cron`) each with a model string and optional `base_url`
- Add a `Goodwizard.Config.model/1` function that resolves a role atom (`:default`, `:subagent`, `:cron`) to its configured model string, falling back to `:default` then to the existing `[agent].model` value
- Add a `Goodwizard.Config.model_base_url/1` companion that returns the `base_url` for a role (or `nil` for standard provider endpoints)
- Wire `Agent`, `SubAgent`, and `CronRunner` to read their model from Config at startup instead of using hardcoded strings
- Pass `base_url` through to ReqLLM calls when configured
- **BREAKING**: The `[agent].model` key becomes the fallback for backward compatibility but is superseded by `[models.default].model` when present

## Capabilities

### New Capabilities
- `model-aliases`: Configurable named model roles (`default`, `fast`, `reasoning`, `subagent`, `cron`) resolved from `config.toml` with per-role provider base URL support

### Modified Capabilities
_(none — no existing specs)_

## Impact

- **Config**: New `[models]` and `[models.*]` TOML tables; existing `[agent].model` preserved as fallback
- **Code**: `Config`, `Agent`, `SubAgent`, `CronRunner`, `CronLoader` modules updated to read model from Config
- **Dependencies**: No new deps — uses existing ReqLLM `base_url` option pass-through
- **Setup**: `mix goodwizard.setup` default config template updated with commented `[models]` section
