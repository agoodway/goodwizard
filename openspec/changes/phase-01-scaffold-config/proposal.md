# Phase 1: Project Scaffold and Config

## Why

Goodwizard needs a foundational Elixir project with dependency management, application skeleton, Jido v2 instance module, and TOML-based configuration loading before any agent logic can be built. This is the first step in rebuilding Nanobot in Elixir on Jido v2 (2.0.0-rc.4).

## What

Create the Mix project `goodwizard` with:

- **mix.exs** with deps: `jido ~> 2.0.0-rc`, `jido_ai ~> 0.5`, `jido_character ~> 1.0`, `jido_browser ~> 0.8`, `jido_messaging ~> 0.1`, `telegex ~> 1.8`, `finch ~> 0.18`, `toml ~> 0.7`, `jason ~> 1.4`
- **Goodwizard.Jido** instance module (`use Jido, otp_app: :goodwizard`) for agent lifecycle management
- **Goodwizard.Messaging** module (`use JidoMessaging, adapter: JidoMessaging.Adapters.ETS`) for all messaging infrastructure — rooms, participants, messages, signal bus, and channel supervision
- **Goodwizard.Application** supervision tree starting Config + Jido + Messaging
- **Goodwizard.Config** GenServer that loads `~/.goodwizard/config.toml` + env var overrides

### Why jido_ai instead of req_llm

jido_ai (from the same agentjido team) provides:
- ReAct strategy with built-in tool loop (eliminates custom ToolLoop strategy)
- Tool registry, executor, and adapter (eliminates custom ToolBuilder)
- ReActAgent macro for agent definitions with ask/await pattern
- Multi-provider model abstraction with keyring management
- Multiple reasoning strategies (CoT, ToT, GoT, TRM, Adaptive) for free
- req_llm is pulled in transitively

### Config Details

Port of `nanobot/config/schema.py`. TOML structure:

```toml
[agent]
workspace = "~/.goodwizard/workspace"
model = "anthropic:claude-sonnet-4-5"
max_tokens = 8192
temperature = 0.7
max_tool_iterations = 20
memory_window = 50

[channels.cli]
enabled = true

[channels.telegram]
enabled = false
allow_from = []

[tools.exec]
timeout = 60

[tools]
restrict_to_workspace = false

[character]
name = "Goodwizard"
tone = "helpful"
style = "concise technical"
traits = ["analytical", "patient", "thorough"]

[browser]
headless = true
adapter = "vibium"
timeout = 30000

[browser.search]
brave_api_key = ""
```

The `[character]` section is optional — when absent, defaults from `Goodwizard.Character` are used. When present, values override the module defaults.

Env var overrides (higher priority than TOML):
- `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` → used by jido_ai keyring directly
- `TELEGRAM_BOT_TOKEN` → wired to `config :telegex, token:` in `runtime.exs`
- `BRAVE_API_KEY` → `browser.search.brave_api_key`
- `GOODWIZARD_WORKSPACE` → `agent.workspace`
- `GOODWIZARD_MODEL` → `agent.model`

Init logic: Read TOML → deep merge env overrides → store in GenServer state. Create workspace dir if missing. Wire browser config into `:jido_browser` application env. `Config.get(:character)` returns the `[character]` map (or `nil` if absent) for use by `Goodwizard.Character` at hydration time.

### Telegex Configuration

Telegex (the Telegram bot library used by jido_messaging) requires two config entries:

- **`config.exs`**: Set the Telegex caller adapter — `config :telegex, caller_adapter: {Telegex.Caller.FinchAdapter, [receive_timeout: 60_000]}`
- **`runtime.exs`**: Wire `TELEGRAM_BOT_TOKEN` env var — `config :telegex, token: System.get_env("TELEGRAM_BOT_TOKEN")`

The bot token is NOT stored in `config.toml` or `Goodwizard.Config`. Telegex reads it directly from application config.

### Goodwizard.Messaging

`Goodwizard.Messaging` uses `use JidoMessaging, adapter: JidoMessaging.Adapters.ETS` to provide all messaging infrastructure: rooms, participants, messages, a signal bus, deduplication, and channel supervision. It replaces a custom `ChannelSupervisor` that would otherwise be needed. The module starts as a supervised child after Jido in the application supervision tree.

**Note**: On first run, `mix jido_browser.install` downloads the platform-appropriate Vibium browser binary (~10MB). This is a compile-time task that must run before first use.

## Dependencies

None — this is the foundation phase.

## Reference

- `nanobot/config/schema.py` (289 lines)
- Jido v2 docs: https://hexdocs.pm/jido/2.0.0-rc.4/readme.html
- jido_ai docs: https://hexdocs.pm/jido_ai/readme.html
