## Context

After `specializedagent-signal-communication`, the Spawn action supports async mode — it emits `SpawnAgent` directives and returns immediately, with results delivered via signals to the SubagentRouter and stored in Cache. `SpawnMany` builds on this by spawning multiple agents in async mode and polling Cache for all results.

The BEAM excels at concurrent work. Jido's `SpawnAgent` directive handles parent-child tracking per agent, and the SubagentRouter collects results as they arrive.

## Goals / Non-Goals

**Goals:**
- Spawn 2+ specializedagents concurrently from a single action call
- Collect results with configurable strategies (all, any, race)
- Respect global concurrency limit (`@max_concurrent_specializedagents`)
- Clean up all spawned agents regardless of success/failure

**Non-Goals:**
- Subagent-to-specializedagent communication during execution (separate proposal)
- Workflow chaining (output of one feeds into another) — that's orchestration
- Dynamic scaling based on load

## Decisions

### 1. Task list as action input, not individual parameters

**Choice**: `SpawnMany` accepts a `tasks` list where each entry is `%{task: string, agent_name: string (optional), label: string (optional)}`.

**Rationale**: A list is the natural shape for fan-out. Labels let the main agent refer to specific results in follow-up reasoning.

### 2. Three collection strategies

**Choice**:
- `:all` — Wait for every specializedagent to complete. Return all results. Default.
- `:any` — Return as soon as any one specializedagent completes. Cancel the rest.
- `:race` — Same as `:any` but emphasizes first-wins semantics.

**Rationale**: `:all` is the common case (parallel research). `:any`/`:race` enable "try multiple approaches, use the first good answer" patterns.

**Implementation**: `:all` uses `Task.await_many/2`. `:any`/`:race` use `Task.yield_many/2` with early termination.

### 3. Concurrency limit applies to total active specializedagents

**Choice**: If 2 specializedagents are already running and the limit is 5, `SpawnMany` can spawn at most 3 more. If the task list exceeds available slots, return an error — don't partially execute.

**Rationale**: Partial execution creates confusing results. Better to fail fast and let the main agent reduce the batch size.

### 4. Guaranteed cleanup via after block

**Choice**: All spawned agent PIDs tracked in a list. `after` block iterates and calls `stop_agent` on each, regardless of outcome.

**Rationale**: Matches existing `Spawn` pattern. Prevents orphaned processes.

## Risks / Trade-offs

- **All-or-nothing on limit** — Rejecting a batch when slots are partially available might frustrate the LLM. Mitigation: include available slot count in the error message so the agent can retry with fewer tasks.
- **Timeout coordination** — Each specializedagent has its own timeout from config. `Task.await_many` needs a global timeout. Use `max(individual timeouts) + buffer` as the await timeout.
