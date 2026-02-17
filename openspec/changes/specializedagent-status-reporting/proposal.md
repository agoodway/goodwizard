## Why

When the main agent spawns specializedagents — especially in parallel — there's no visibility into what's happening. The user sees silence until all work completes. The main agent can't check progress or report status. For an "AI workforce" to feel like a team, the user needs to see which agents are active, what they're working on, and when they finish.

## What Changes

- Add telemetry events for specializedagent lifecycle: spawn, progress, complete, error.
- Add a new `Goodwizard.Actions.Subagent.Status` action that returns a snapshot of all active specializedagents (name, role, task description, elapsed time).
- Attach telemetry handlers that update a lightweight agent registry in ETS (via Cache) tracking active specializedagent metadata.
- Update `Spawn` and `SpawnMany` to emit telemetry events at each lifecycle stage.

## Capabilities

### New Capabilities

- `specializedagent-status-reporting`: Query active specializedagent status and emit lifecycle telemetry events for observability.

### Modified Capabilities

- `specializedagent-spawn`: Emits telemetry events on spawn, completion, and error.
- `specializedagent-parallel-spawn`: Emits telemetry events per spawned specializedagent.

## Impact

- **New files**: `lib/goodwizard/actions/specializedagent/status.ex`, `lib/goodwizard/specializedagent_telemetry.ex`
- **Modified files**: `lib/goodwizard/actions/specializedagent/spawn.ex` (add telemetry calls), `lib/goodwizard/actions/specializedagent/spawn_many.ex` (add telemetry calls), `lib/goodwizard/agent.ex` (add Status to tools list), `lib/goodwizard/application.ex` (attach telemetry handler on startup)
- **Dependencies**: `:telemetry` (already a transitive dep via Phoenix/Jido)

## Prerequisites

- `specializedagent-parallel-spawn`
