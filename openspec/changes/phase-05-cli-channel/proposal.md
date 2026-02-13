# Phase 5: CLI Channel

## Why

The CLI is the primary development and testing interface — the first way to interact with the fully wired agent. This phase connects all prior work into a working REPL and completes the supervision tree, making Goodwizard usable for the first time.

## What

### Goodwizard.ChannelSupervisor

DynamicSupervisor for channel processes. Provides `start_channel/2` to launch channel GenServers on demand.

### Goodwizard.Channels.CLI.Server

GenServer that reads stdin and dispatches to an AgentServer via the Jido instance.

- On init: read workspace from Config, start AgentServer via `Goodwizard.Jido.start_agent/2` with id `"cli:direct"`
- REPL loop in a linked Task: `IO.gets("you> ")` → call `ask_sync/3` → print response
- Uses jido_ai's `ask_sync/3` pattern with 120s timeout

```elixir
# In the REPL loop:
{:ok, answer} = Goodwizard.Agent.ask_sync(pid, input, timeout: 120_000)
IO.puts("\ngoodwizard> #{answer}\n")
```

### Updated Application Supervision Tree

```elixir
children = [
  {Goodwizard.Config, []},
  {Goodwizard.Jido, []},
  {Goodwizard.ChannelSupervisor, []}
]
```

### Mix Tasks

**mix goodwizard.setup** — Create workspace dirs (`~/.goodwizard/workspace/`, `memory/`, `skills/`, `sessions/`) and write default `config.toml` if missing.

**mix goodwizard.cli** — Start application, launch CLI channel via ChannelSupervisor, keep alive.

## Dependencies

- Phase 4 (Agent Definition)

## Reference

- This is the integration milestone — first end-to-end test of the full system
