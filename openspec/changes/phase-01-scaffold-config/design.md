## Context

Goodwizard is a rebuild of Nanobot (Python) in Elixir, using Jido v2 (2.0.0-rc.4) as the agent framework and jido_ai for LLM integration. This is phase 1: creating the project scaffold, dependency management, configuration loading, and the Jido instance module. No agent logic exists yet — this establishes the foundation everything else builds on.

The original Nanobot uses a Python config schema (~289 lines) with TOML-based configuration. We port that pattern to Elixir with a GenServer-backed config module.

## Goals / Non-Goals

**Goals:**
- Compilable Mix project with all core dependencies resolved
- Goodwizard.Config GenServer that loads `~/.goodwizard/config.toml` with env var overrides
- Goodwizard.Jido instance module wired into the supervision tree
- Test suite proving config loading, env overrides, defaults, and path expansion

**Non-Goals:**
- Agent definitions, tools, or reasoning strategies (phase 2+)
- Channel implementations (CLI, Telegram) beyond config stubs
- Runtime hot-reloading of config
- Config persistence (write-back to TOML)

## Decisions

### 1. GenServer for Config vs Application env

**Decision**: Use a dedicated GenServer (`Goodwizard.Config`) rather than `Application.put_env/get_env`.

**Rationale**: GenServer gives us a single load-once-at-startup pattern with clean API (`Config.get/0`, `Config.get/1`), easy testability via process isolation, and a path toward future features (reload, watch) without changing the interface. Application env is global mutable state that's harder to test and reason about.

**Alternatives considered**: ETS table (faster reads but more complexity for a config that rarely changes), persistent_term (good perf but awkward updates).

### 2. jido_browser for all web/browser operations

**Decision**: Use `jido_browser ~> 0.8` for all web and browser automation capabilities.

**Rationale**: Same agentjido ecosystem as jido/jido_ai. Provides browser automation via Plugin pattern — 31 actions including SearchWeb (Brave API), ReadPage (fetch+extract), full DOM interaction, screenshots, and JavaScript execution. Eliminates the need for custom `Web.Search` and `Web.Fetch` action modules. Req is now a transitive dependency via jido_browser rather than a direct dependency.

**Alternatives considered**: Custom Web.Search/Web.Fetch actions using Req directly — rejected because jido_browser provides all this and more (proper HTML-to-markdown conversion, session management, browser automation) with zero custom code.

### 3. TOML via `toml` hex package

**Decision**: Use the `toml` hex package (~> 0.7) for parsing.

**Rationale**: Direct port of Nanobot's TOML config format. The `toml` package is mature, pure Elixir, no NIFs. Keeps config files compatible with the Python version during migration.

### 4. Config merge strategy: TOML defaults → file → env vars

**Decision**: Three-layer merge — hardcoded defaults, then TOML file overrides, then env var overrides (highest priority).

**Rationale**: Matches Nanobot's behavior. Env vars must win for container/CI deployments. Hardcoded defaults ensure the app always starts even without a config file.

### 5. Jido instance module as supervised child

**Decision**: `Goodwizard.Jido` uses `use Jido, otp_app: :goodwizard` and starts under the Application supervisor after Config.

**Rationale**: Jido v2's instance module pattern manages agent lifecycle. Starting it after Config ensures config values are available when Jido initializes.

### 6. Flat map with dot-path keys for config access

**Decision**: Config.get/1 accepts dot-path atoms like `:agent.model` or nested list `[:agent, :model]`.

**Rationale**: Simpler API than nested map traversal. Internal storage stays as nested maps for merge operations; access is flattened at the API boundary.

### 7. jido_messaging for all messaging infrastructure

**Decision**: Use `jido_messaging ~> 0.1` (`use JidoMessaging`) for rooms, participants, messages, signal bus, and channel supervision. `Goodwizard.Messaging` replaces a custom `ChannelSupervisor`.

**Rationale**: Same agentjido ecosystem. jido_messaging provides a Channel behaviour, built-in Telegram support via Telegex, rooms/participants/messages domain model, RoomServer with bounded history, AgentRunner for signal-driven agent dispatch, and a full supervision tree. Using it eliminates ~3 custom modules (ChannelSupervisor, Telegram.Poller, Telegram.Sender) and gives multi-channel capabilities (Discord, Slack, WhatsApp) for free. Telegex (`~> 1.8`) is the underlying Telegram bot library, and Finch (`~> 0.18`) is its HTTP adapter.

**Alternatives considered**: Custom DynamicSupervisor for channels — rejected because jido_messaging provides all of this plus rooms, message persistence, and ingest/deliver pipelines.

## Risks / Trade-offs

**[Jido v2 RC instability]** → Pin to exact RC version (2.0.0-rc.4), vendor lock file, and test on each RC bump. The RC API could change before stable release.

**[TOML parsing edge cases]** → The `toml` package handles the TOML spec well but we should validate config structure after parsing rather than trusting arbitrary TOML input. Phase 1 uses simple key presence checks; schema validation can come later.

**[Config file missing on first run]** → Use hardcoded defaults so the app starts cleanly. Log a warning pointing users to create the config file. Don't auto-generate a config file (avoids write-permission issues).

**[Path expansion (~)]** → Elixir doesn't expand `~` natively. Use `Path.expand/1` which handles this. Test explicitly.

**[jido_messaging 0.1 is new]** → Pre-1.0 API may change. Mitigate by pinning to exact version (`~> 0.1.0`), wrapping access through `Goodwizard.Messaging` module so internal API changes are isolated.
