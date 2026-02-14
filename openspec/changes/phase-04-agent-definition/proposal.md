# Phase 4: Agent Definition

## Why

The Goodwizard agent needs a formal definition that wires together the ReAct strategy, tool actions, and session management into a single coherent entity. Using jido_ai's `ReActAgent` macro, this becomes a declarative definition rather than manual skill composition — the macro handles strategy wiring, request tracking, and task supervision automatically.

## What

### Goodwizard.Agent (ReActAgent)

The main agent definition using jido_ai's `ReActAgent` macro:

```elixir
defmodule Goodwizard.Agent do
  use Jido.AI.ReActAgent,
    name: "goodwizard",
    description: "Personal AI assistant",
    tools: [
      Goodwizard.Actions.Filesystem.ReadFile,
      Goodwizard.Actions.Filesystem.WriteFile,
      Goodwizard.Actions.Filesystem.EditFile,
      Goodwizard.Actions.Filesystem.ListDir,
      Goodwizard.Actions.Shell.Exec
    ],
    system_prompt: nil,  # Built dynamically by Character + Hydrator
    model: "anthropic:claude-sonnet-4-5",
    max_iterations: 20
end
```

The `ReActAgent` macro provides:
- ReAct strategy wired automatically (no custom ToolLoop needed)
- `ask/2,3` — async query, returns `{:ok, %Request{}}` for later awaiting
- `await/1,2` — await a request's completion
- `ask_sync/2,3` — synchronous convenience wrapper
- `on_before_cmd/2` and `on_after_cmd/3` — hooks for session/memory integration
- Per-instance Task.Supervisor for async operations
- Request tracking for concurrent conversations

### Goodwizard.Skills.Session (Jido Skill)

In-memory message history per conversation. Port of `nanobot/session/manager.py:Session` (lines 15-58). Persistence comes in Phase 6.

- State key: `:session`
- Schema: messages (list, default []), created_at (string), metadata (map)
- Helper functions: `add_message/4`, `get_history/2`, `clear/1`

### System Prompt Integration

The ReAct strategy accepts a `system_prompt` option, but Goodwizard's system prompt is dynamic (built from workspace files, memory, skills). We need to hook into the agent lifecycle to build the system prompt via Character + Hydrator before each ReAct cycle:

- Override `on_before_cmd/2` to call `Goodwizard.Character.Hydrator.hydrate/2` with workspace state
- Hydrator creates a fresh character, applies config overrides, injects bootstrap files/memory/skills as knowledge
- Character overrides from agent `initial_state` (if any) are applied via the Hydrator
- Set the rendered prompt into the ReAct strategy's conversation

### Agent Creation Pattern

```elixir
# Start via Jido instance (OTP supervised)
{:ok, pid} = Goodwizard.Jido.start_agent(Goodwizard.Agent,
  id: "cli:direct",
  initial_state: %{workspace: "/path", channel: "cli", chat_id: "direct"}
)

# Async pattern (preferred)
{:ok, request} = Goodwizard.Agent.ask(pid, "Hello, what can you do?")
{:ok, answer} = Goodwizard.Agent.await(request, timeout: 120_000)

# Sync convenience
{:ok, answer} = Goodwizard.Agent.ask_sync(pid, "List the files in /tmp", timeout: 120_000)
```

## Dependencies

- Phase 3 (ReAct Integration) — Character, Hydrator, ContextBuilder, and tool registration

## Reference

- `nanobot/session/manager.py:Session` (lines 15-58)
- jido_ai ReActAgent: https://hexdocs.pm/jido_ai/Jido.AI.ReActAgent.html
- jido_ai strategies: https://hexdocs.pm/jido_ai/readme.html
