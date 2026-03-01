## Why

Goodwizard stores API keys and bot tokens as plaintext in `.env` files and environment variables. This creates security risk — credentials on disk, accidental commits, no rotation support. 1Password CLI (`op read`) can resolve secret references at runtime, replacing plaintext with vault-backed `op://` URIs that are safe to commit and automatically stay in sync with credential rotation.

## What Changes

- **New `Goodwizard.Secrets` module** — stateless utility that detects `op://` prefixed strings and resolves them by shelling out to `op read`. Caches resolved values in `Goodwizard.Cache` with configurable TTL.
- **Config.ex secret resolution** — after the three-layer merge (defaults → TOML → env vars), walk the config map and resolve any `op://` values transparently. Actions calling `Config.get/1` receive resolved plaintext without knowing about 1Password.
- **Application env var resolution** — detect `op://` literals in env vars set by Dotenvy (e.g., `TELEGRAM_BOT_TOKEN`, `ANTHROPIC_API_KEY`) and resolve them post-boot via `System.put_env` and `Application.put_env` so downstream libraries (Telegex, ReqLLM) see real credentials.
- **Graceful fallback** — if `op` CLI is not installed or not authenticated, log a warning and pass through the literal `op://` string. App starts in degraded mode (API calls fail with auth errors) but does not crash.
- **New `[secrets]` config section** — `cache_ttl_minutes` option in `config.toml` controlling how long resolved secrets are cached in memory.

## Capabilities

### New Capabilities

- `secret-resolution`: Transparent resolution of `op://` secret references via 1Password CLI, including map walking, caching, graceful fallback, and env var fixup.

### Modified Capabilities

_(none — no existing spec-level requirements change; this adds a new resolution step to Config.init without altering the Config API contract)_

## Impact

- **`lib/goodwizard/config.ex`** — two new private functions in `init/1` pipeline: `resolve_secrets/2` (walks config map) and `resolve_app_env_secrets/1` (fixes env vars)
- **`lib/goodwizard/secrets.ex`** — new module (no GenServer, no supervision tree changes)
- **`config.toml`** — new commented `[secrets]` section
- **`lib/mix/tasks/goodwizard.setup.ex`** — `@default_config` gets `[secrets]` section
- **`lib/goodwizard/cache.ex`** — used for TTL caching of resolved secrets (no modifications needed)
- **External dependency**: requires `op` CLI installed and authenticated on the host (not an Elixir dep)
- **Startup latency**: adds ~100-500ms per secret resolved (3-5 secrets = ~1-2s one-time at boot)
