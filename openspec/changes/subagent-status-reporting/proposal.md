## Why

When the main agent spawns subagents — especially in parallel — there's no visibility into what's happening. The user sees silence until all work completes. The main agent can't check progress or report status. For an "AI workforce" to feel like a team, the user needs to see which agents are active, what they're working on, and when they finish.

## What Changes

- Add telemetry events for subagent lifecycle: spawn, progress, complete, error.
- Add a new `Goodwizard.Actions.Subagent.Status` action that returns a snapshot of all active subagents (name, role, task description, elapsed time).
- Attach telemetry handlers that update a lightweight agent registry in ETS (via Cache) tracking active subagent metadata.
- Update `Spawn` and `SpawnMany` to emit telemetry events at each lifecycle stage.

## Capabilities

### New Capabilities

- `subagent-status-reporting`: Query active subagent status and emit lifecycle telemetry events for observability.

### Modified Capabilities

- `subagent-spawn`: Emits telemetry events on spawn, completion, and error.
- `subagent-parallel-spawn`: Emits telemetry events per spawned subagent.

## Impact

- **New files**: `lib/goodwizard/actions/subagent/status.ex`, `lib/goodwizard/subagent_telemetry.ex`
- **Modified files**: `lib/goodwizard/actions/subagent/spawn.ex` (add telemetry calls), `lib/goodwizard/actions/subagent/spawn_many.ex` (add telemetry calls), `lib/goodwizard/agent.ex` (add Status to tools list), `lib/goodwizard/application.ex` (attach telemetry handler on startup)
- **Dependencies**: `:telemetry` (already a transitive dep via Phoenix/Jido)

## Prerequisites

- `subagent-parallel-spawn`
