## Context

Goodwizard uses a three-layer config merge (defaults → TOML → env vars) in `Goodwizard.Config`, a GenServer that starts early in the supervision tree. Credentials are consumed by:

- **Telegex** — reads `Application.get_env(:telegex, :token)` on every API call
- **ReqLLM** — reads `System.get_env("ANTHROPIC_API_KEY")` on every LLM request
- **JidoBrowser** — reads `Application.get_env(:jido_browser, :brave_search_api_key)` once at config init

Dotenvy loads `.env` at compile/boot time in `config/runtime.exs`, before OTP apps start. If `.env` contains `op://` URIs, Dotenvy sets the literal string as the env var value. Our code must resolve these after OTP startup.

The supervision tree order is: Config → Cache → Jido → Messaging → Channels. Cache starts **after** Config, so caching is unavailable during `Config.init/1`.

## Goals / Non-Goals

**Goals:**
- Transparently resolve `op://` secret references so `Config.get/1` returns plaintext values
- Fix env vars and Application config so downstream libs (Telegex, ReqLLM) see resolved credentials
- Cache resolved secrets in `Goodwizard.Cache` with configurable TTL for any post-boot resolution
- Gracefully degrade when `op` CLI is missing or not authenticated (warn, don't crash)
- Allow `.env` and `config.toml` to contain `op://` URIs that are safe to commit

**Non-Goals:**
- Boot-time `op run` wrapper (user can still use `op run` externally but we don't require it)
- Agent-visible secret fetching action (no `FetchSecret` tool — secrets are config-only)
- Secret rotation without restart (initial version resolves at boot; cache TTL handles eventual re-resolution for post-boot paths)
- Writing secrets back to 1Password
- Supporting secret managers other than 1Password CLI

## Decisions

### 1. Stateless utility module, not a GenServer

`Goodwizard.Secrets` is a plain module with pure functions (plus a shell-out side effect). No process, no supervision tree entry.

**Rationale**: Secrets resolution is a one-time boot concern. Adding a GenServer would add lifecycle complexity for no benefit. The module is callable from `Config.init/1` without process coordination.

**Alternative considered**: GenServer that pre-resolves and stores secrets → rejected because Config already stores the resolved values and Cache handles TTL.

### 2. Resolve eagerly in Config.init, not lazily on Config.get

All `op://` values in the config map are resolved synchronously during `Config.init/1`, after `apply_env_overrides` and before `validate_numeric_ranges`.

**Rationale**: Config values are consumed immediately by `wire_browser_config`, `ensure_workspace`, etc. Lazy resolution would require modifying every `Config.get/1` call path and add latency to the first access of each key. Eager resolution adds ~1-2s to startup (acceptable for 3-5 secrets at ~200-500ms each).

**Alternative considered**: Lazy resolution with memoization → rejected for complexity and race conditions during init.

### 3. Post-boot env var fixup for Dotenvy-loaded values

A new `resolve_app_env_secrets/1` step in `Config.init/1` checks `Application.get_env(:telegex, :token)` and `System.get_env("ANTHROPIC_API_KEY")`/`"OPENAI_API_KEY"` for `op://` prefixes, resolves them, and calls both `System.put_env` and `Application.put_env`.

**Rationale**: Dotenvy runs in `config/runtime.exs` before OTP apps start — we cannot call our modules there. But `Config.init/1` runs during supervision tree startup, after the BEAM is up. `System.put_env` is process-global and updates the BEAM VM's environment so `ReqLLM.Keys` (which calls `System.get_env` on every request) sees resolved values.

### 4. Runner injection for testing

`Secrets.resolve/2` accepts a `:runner` option (default: `&System.cmd/3`) so tests can inject a mock without Mox or process dictionaries. Config passes `:secrets_runner` from its `start_link` opts through to `Secrets`.

**Rationale**: Simple dependency injection. Tests create a closure that returns `{secret, 0}` or `{error, 1}`. No global state, no mocking framework needed.

### 5. Cache-aware but cache-optional

`Secrets` checks `Process.whereis(Goodwizard.Cache)` before attempting cache reads/writes. During `Config.init/1` (before Cache starts), this returns `nil` and caching is silently skipped. Post-boot resolution calls benefit from caching.

**Rationale**: Avoids a hard dependency on Cache startup order. The primary path (boot-time) doesn't need caching anyway since each secret is resolved exactly once and stored in Config's GenServer state.

### 6. URI redaction in logs

Log messages show vault and item names but redact the field: `op://Vault/Item/***`. Never log resolved secret values.

**Rationale**: Field names may hint at the secret type. Vault/item context is needed for debugging resolution failures.

## Risks / Trade-offs

- **Startup latency** — Each `op read` call takes 100-500ms. 3-5 secrets = ~1-2s added to boot. → Acceptable for an agent that runs long-lived. Can parallelize with `Task.async_stream` later if needed.

- **Biometric prompt in interactive mode** — `op read` on macOS may trigger Touch ID. → Expected for CLI use. For daemon/headless deployments, use 1Password service accounts (no biometric). Document this.

- **`System.put_env` is BEAM-global** — Resolved secrets are visible to any code reading the env var. → The env var already contained the plaintext secret before this change. No security regression.

- **`op` CLI version dependency** — Requires `op` v2.x with `read` command and `--no-newline` flag. → Document minimum version requirement. The `--no-newline` flag has been stable since op v2.0.

- **Cache vs. no Cache at boot** — Config starts before Cache, so boot-time resolution is uncached. → This is fine — boot resolution runs once and stores results in Config state. Only matters if someone calls `Secrets.resolve/2` directly post-boot (rare).
