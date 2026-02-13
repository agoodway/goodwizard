# Phase 1: Project Scaffold and Config

## Why

Goodwizard needs a foundational Elixir project with dependency management, application skeleton, Jido v2 instance module, and TOML-based configuration loading before any agent logic can be built. This is the first step in rebuilding Nanobot in Elixir on Jido v2 (2.0.0-rc.4).

## What

Create the Mix project `goodwizard` with:

- **mix.exs** with deps: `jido ~> 2.0.0-rc`, `jido_ai ~> 0.5`, `toml ~> 0.7`, `jason ~> 1.4`
- **Goodwizard.Jido** instance module (`use Jido, otp_app: :goodwizard`) for agent lifecycle management
- **Goodwizard.Application** supervision tree starting Config + Jido
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
token = ""
allow_from = []

[tools.exec]
timeout = 60

[tools.web.search]
api_key = ""

[tools]
restrict_to_workspace = false
```

Env var overrides (higher priority than TOML):
- `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` → used by jido_ai keyring directly
- `TELEGRAM_BOT_TOKEN` → `channels.telegram.token`
- `BRAVE_API_KEY` → `tools.web.search.api_key`
- `GOODWIZARD_WORKSPACE` → `agent.workspace`
- `GOODWIZARD_MODEL` → `agent.model`

Init logic: Read TOML → deep merge env overrides → store in GenServer state. Create workspace dir if missing.

## Dependencies

None — this is the foundation phase.

## Reference

- `nanobot/config/schema.py` (289 lines)
- Jido v2 docs: https://hexdocs.pm/jido/2.0.0-rc.4/readme.html
- jido_ai docs: https://hexdocs.pm/jido_ai/readme.html
