# Phase 5: CLI Channel

## Why

The CLI is the primary development and testing interface — the first way to interact with the fully wired agent. This phase connects all prior work into a working REPL, making Goodwizard usable for the first time.

## What

### Goodwizard.Channels.CLI.Server

GenServer that reads stdin and dispatches to an AgentServer via the Jido instance.

- On init: read workspace from Config, create a Messaging room via `Goodwizard.Messaging.get_or_create_room_by_external_binding(:cli, "goodwizard", "direct")`, start AgentServer via `Goodwizard.Jido.start_agent/2` with id `"cli:direct"`
- REPL loop in a linked Task: `IO.gets("you> ")` → save user message to room → call `ask_sync/3` → save assistant message to room → print response
- Uses jido_ai's `ask_sync/3` pattern with 120s timeout

```elixir
# In the REPL loop:
Goodwizard.Messaging.save_message(%{room_id: room_id, sender_id: "user", content: input})
{:ok, answer} = Goodwizard.Agent.ask_sync(pid, input, timeout: 120_000)
Goodwizard.Messaging.save_message(%{room_id: room_id, sender_id: "assistant", content: answer})
IO.puts("\ngoodwizard> #{answer}\n")
```

### Application Supervision Tree

The supervision tree from Phase 1 already includes everything needed:

```elixir
children = [
  {Goodwizard.Config, []},
  {Goodwizard.Jido, []},
  {Goodwizard.Messaging, []}
]
```

No `ChannelSupervisor` is needed — `Goodwizard.Messaging` (via jido_messaging) provides room supervision, signal bus, and channel management.

### Mix Tasks

**mix goodwizard.setup** — Create workspace dirs (`priv/workspace/memory/`, `priv/workspace/sessions/`, `priv/workspace/skills/`) and write default `config.toml` to the project root if missing.

**mix goodwizard.cli** — Start application, launch CLI Server directly, keep alive.

## Dependencies

- Phase 4 (Agent Definition)

## Reference

- This is the integration milestone — first end-to-end test of the full system
