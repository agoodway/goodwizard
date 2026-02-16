## Context

Jido's agent system has two ways to spawn child agents:

1. **Manual** (what Goodwizard does today): `Jido.start_agent(SubAgent, id: id)` + `SubAgent.ask_sync(pid, query)`. No parent-child tracking. No signals. Synchronous only.

2. **Directive-based** (what Jido provides): `Directive.SpawnAgent` creates a child with `__parent__` in its state. Parent automatically receives `jido.agent.child.started` and `jido.agent.child.exit` signals. Child can call `Directive.emit_to_parent(agent, signal)` to send signals back.

The current manual approach was fine for a single synchronous subagent. For an AI workforce with parallel agents, progress tracking, and eventual workflow integration, the directive-based model is the right foundation.

## Goals / Non-Goals

**Goals:**
- Switch Spawn action internals to use `Directive.SpawnAgent`
- Subagents can emit structured progress signals during their work
- Main agent receives and stores child signals for status queries
- Support both sync (block until done) and async (return immediately) spawn modes
- Preserve backwards compatibility — sync mode is the default

**Non-Goals:**
- Subagent-to-subagent (sibling) communication — future proposal
- Main agent sending follow-up signals to a running subagent (clarification) — future proposal
- Streaming subagent output to the user in real-time — depends on channel capabilities

## Decisions

### 1. Switch from ask_sync to SpawnAgent directive

**Choice**: The Spawn action emits a `Directive.SpawnAgent` instead of manually calling `start_agent`. The main agent's strategy processes the directive, which sets up parent-child tracking automatically.

**Rationale**: `SpawnAgent` gives us `__parent__` on the child, lifecycle signals on the parent, and proper monitoring — all for free. The manual approach reimplements a subset of this poorly.

**Trade-off**: The Spawn action can no longer be a simple "call and return" — it needs to work with the signal system. In sync mode, it blocks on a signal rather than `ask_sync`. In async mode, it returns immediately.

### 2. Three signal types for subagent communication

**Choice**:

| Signal Type | Direction | Purpose | Data |
|---|---|---|---|
| `goodwizard.subagent.progress` | Child → Parent | Intermediate update | `%{agent_id, role, message, iteration}` |
| `goodwizard.subagent.result` | Child → Parent | Final result | `%{agent_id, role, result}` |
| `goodwizard.subagent.error` | Child → Parent | Failure | `%{agent_id, role, reason}` |

**Rationale**: Minimal set that covers the useful cases. Progress lets the parent report status. Result replaces the `ask_sync` return value. Error replaces exception handling. All use Jido's `Signal.new!` with CloudEvents-compliant structure.

**Alternative considered**: Reusing Jido's built-in `jido.agent.child.exit` for result delivery. Rejected because exit signals only carry exit reason, not structured results. Custom signals are more expressive.

### 3. SubagentRouter plugin on main agent

**Choice**: New plugin `Goodwizard.Plugins.SubagentRouter` with signal patterns matching `goodwizard.subagent.*`. Handlers write received data to Cache under `"subagent:signals:#{agent_id}"`.

**Rationale**: Plugins are the standard way to add signal handlers in Jido. The router collects signals in Cache so the Status action and sync-mode Spawn can read them without coupling to the signal handling directly.

**Cache structure**:
```elixir
# Progress — overwritten on each update (latest only)
Cache.put("subagent:progress:#{agent_id}", %{message: "Found 3 sources", iteration: 4})

# Result — written once on completion
Cache.put("subagent:result:#{agent_id}", %{result: "...", completed_at: timestamp})
```

### 4. Sync mode blocks on Cache polling, not ask_sync

**Choice**: In sync mode, the Spawn action emits `SpawnAgent` + sends the task signal, then polls `Cache.get("subagent:result:#{agent_id}")` with a sleep interval until the result appears or timeout is reached.

**Rationale**: This decouples the Spawn action from the signal handling. The SubagentRouter writes results to Cache; the Spawn action reads from Cache. Simple, testable, no complex process coordination.

**Alternative considered**: Using `receive` to block on a message from the child. Rejected because actions run in the agent's process and blocking with `receive` would prevent the agent from processing other signals.

**Alternative considered**: Using Erlang's `:gen_event` or a `Task` wrapper around signal delivery. Rejected as overengineered for the initial implementation. Cache polling with 500ms intervals is good enough for 120s timeouts.

### 5. EmitProgress action on SubAgent

**Choice**: New `Goodwizard.Actions.Subagent.EmitProgress` action added to SubAgent's tool list. When the subagent calls it during its ReAct loop, it emits a `goodwizard.subagent.progress` signal to the parent via `Directive.emit_to_parent`.

**Rationale**: The subagent is an LLM-driven ReAct agent — it can't emit signals directly. It needs a tool/action it can call. The system prompt for each subagent role can instruct it to report progress at natural checkpoints.

**Schema**: `%{message: string}` — simple text update. The action enriches it with `agent_id`, `role`, and `iteration` from context before emitting.

### 6. Async mode returns agent_id for later status checks

**Choice**: When `async: true` is passed to the Spawn action, it emits the SpawnAgent directive and task signal, then returns `{:ok, %{agent_id: id, role: role, status: :running}}` immediately. The caller uses the Status action to check results later.

**Rationale**: Enables the main agent to spawn work and continue conversing with the user. Essential for the parallel spawn proposal that builds on this.

## Risks / Trade-offs

- **Cache polling latency** — 500ms poll interval means up to 500ms delay between subagent completion and result availability in sync mode. Acceptable for 120s+ tasks.
- **Cache TTL vs orphaned entries** — If a subagent crashes without emitting result/error, the progress entry lingers until TTL expires. The `jido.agent.child.exit` lifecycle signal provides a safety net — the SubagentRouter should handle it and write an error entry.
- **Signal ordering** — Jido doesn't guarantee signal ordering across processes. Progress signals may arrive at the parent after the result signal in rare cases. The router should handle this gracefully (don't overwrite a result with a progress update).
