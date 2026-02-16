## Context

Goodwizard currently hardcodes `"anthropic:claude-sonnet-4-5"` in three places: `Agent` module (line 68), `SubAgent` module (line 29), and `Config.@defaults` (line 15). Only the primary agent model is configurable via `config.toml` `[agent].model`. Subagents and cron runners always use the hardcoded default. There is no way to configure custom provider base URLs (needed for OpenAI-compatible providers like Moonshot, Ollama, vLLM) without code changes.

ReqLLM already supports a `base_url` option on every call, so the plumbing exists — it just needs to be exposed through Goodwizard's config layer.

## Goals / Non-Goals

**Goals:**
- Define named model roles in `config.toml` with model string and optional `base_url`
- Resolve model by role at runtime via `Config.model/1` with a clear fallback chain
- Wire all agent entry points (Agent, SubAgent, CronRunner) to read from Config
- Backward compatible: existing `[agent].model` config continues to work

**Non-Goals:**
- Per-action model overrides (e.g., "use GPT-4 for this one tool call") — out of scope
- Runtime model switching (hot-reload config while running) — restart required
- Provider credential management — API keys stay in `config :req_llm` / env vars as today
- Wiring `base_url` through jido_ai internals — pass it where ReqLLM options are forwarded

## Decisions

### 1. TOML structure: `[models.<role>]` tables

```toml
[models.default]
model = "anthropic:claude-sonnet-4-5"

[models.fast]
model = "anthropic:claude-haiku-4-5"

[models.subagent]
model = "anthropic:claude-haiku-4-5"

[models.cron]
model = "anthropic:claude-haiku-4-5"

# Example: custom provider with base_url
[models.moonshot]
model = "openai:moonshot-v1-128k"
base_url = "https://api.moonshot.ai/v1"
```

**Why tables over flat keys**: Each role may have both `model` and `base_url`. TOML tables group these naturally. The role name is arbitrary — `default`, `fast`, `subagent`, `cron` are conventions, not a fixed enum.

**Alternative considered**: A single `[agent].models` map — rejected because TOML inline tables are hard to read for multiple entries, and nested tables are idiomatic TOML.

### 2. Resolution fallback chain

`Config.model(role)` resolves in this order:

1. `[models.<role>].model` — explicit role config
2. `[models.default].model` — the default role
3. `[agent].model` — legacy config (backward compat)
4. `@defaults["agent"]["model"]` — hardcoded fallback

This means existing configs with only `[agent].model` continue to work unchanged.

### 3. Config API: `model/1` and `model_base_url/1`

```elixir
Config.model(:default)        # => "anthropic:claude-sonnet-4-5"
Config.model(:subagent)       # => "anthropic:claude-haiku-4-5"  (or falls back)
Config.model_base_url(:moonshot) # => "https://api.moonshot.ai/v1"
Config.model_base_url(:default)  # => nil  (use provider default)
```

Both functions are read-only, resolved at call time from the GenServer state.

### 4. Wiring into Agent/SubAgent/CronRunner

The `use Jido.AI.ReActAgent` macro requires a compile-time `model:` option. This value is the initial default — it gets overridden at runtime in `on_before_cmd` or the runner's setup code.

- **Agent**: Already reads `Config.model()` (the 0-arity version). Change to `Config.model(:default)`.
- **SubAgent**: Hardcoded today. Change to read `Config.model(:subagent)` at spawn time via the `Spawn` action.
- **CronRunner**: Already accepts a `:model` option. Default it to `Config.model(:cron)` when not explicitly set by the cron job.

### 5. Passing `base_url` to ReqLLM

ReqLLM accepts `base_url` as an option in `generate_text/3` and `stream_text/3`. Jido AI's `LLMClient.ReqLLM` forwards options through. When `Config.model_base_url(role)` returns a non-nil value, include it in the options map passed to the LLM call.

The exact injection point depends on how Jido AI constructs its ReqLLM calls — this needs investigation during implementation to find where model options are assembled.

## Risks / Trade-offs

- **[Risk] base_url pass-through may not reach ReqLLM** → Mitigation: Verify Jido AI's `LLMClient.ReqLLM` actually forwards arbitrary options. If not, this becomes a jido_ai upstream issue (document and defer `base_url` support).
- **[Risk] Compile-time model in `use` macro vs runtime config** → Mitigation: The macro default is only used if no runtime override happens. All paths already override at runtime, so the macro value is effectively dead code. Keep it as a safety net.
- **[Trade-off] No validation of role names** → Role names are free-form strings. Typos like `Config.model(:subagnet)` silently fall back to `:default`. This is acceptable — it follows the existing pattern where missing config falls back gracefully.
