## Why

The current Spawn action is synchronous — the main agent blocks until the specializedagent finishes. For an "AI workforce" pattern, the main agent needs to fan out multiple tasks in parallel (e.g., "research competitors" + "draft pricing copy" + "review existing code" simultaneously) and collect results when they complete.

Jido provides `await_all` and `await_any` primitives but the Spawn action doesn't expose parallel execution.

## What Changes

- Add a new `Goodwizard.Actions.Subagent.SpawnMany` action that accepts a list of tasks (each with optional `agent_name`) and spawns them in parallel.
- Support three collection strategies: `:all` (wait for every result), `:any` (return first result), `:race` (return first, cancel rest).
- Enforce the existing concurrency limit across all parallel spawns.
- Aggregate results into a structured map keyed by task index or label.
- Register `SpawnMany` in the main agent's tools list.

## Capabilities

### New Capabilities

- `specializedagent-parallel-spawn`: Spawn multiple named specializedagents in parallel with configurable result collection strategies.

### Modified Capabilities

- `specializedagent-spawn`: Unchanged. `SpawnMany` is a new action, not a modification of `Spawn`.

## Impact

- **New files**: `lib/goodwizard/actions/specializedagent/spawn_many.ex`
- **Modified files**: `lib/goodwizard/agent.ex` (add SpawnMany to tools list)
- **Dependencies**: None new — builds on signal-based spawn from `specializedagent-signal-communication`

## Prerequisites

- `specializedagent-signal-communication`
