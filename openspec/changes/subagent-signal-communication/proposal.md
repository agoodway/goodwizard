## Why

Subagents currently use a fire-and-wait pattern: `ask_sync` blocks the main agent until the subagent finishes, returns a single result string, then the process is killed. There is no way for a subagent to report progress mid-task, send partial results, or signal completion asynchronously.

Jido provides a full parent-child signal system (`Directive.SpawnAgent`, `emit_to_parent`, lifecycle signals) that Goodwizard doesn't use. The Spawn action bypasses it entirely with manual `start_agent` + `Task.Supervisor.async`.

This proposal switches the subagent lifecycle to Jido's directive-based parent-child model so subagents can communicate with the main agent through structured signals.

## What Changes

- Replace the manual `start_agent` + `ask_sync` pattern in the Spawn action with `Directive.SpawnAgent`, which gives children a `__parent__` reference and gives the parent automatic lifecycle signals (`child.started`, `child.exit`).
- Define Goodwizard-specific signal types for subagent communication: `goodwizard.subagent.progress`, `goodwizard.subagent.result`, `goodwizard.subagent.error`.
- Add a `Goodwizard.Plugins.SubagentRouter` plugin on the main agent that handles incoming child signals — stores progress updates and results in Cache, keyed by agent ID.
- Give SubAgent an `emit_progress` helper action so subagents can send intermediate updates during their ReAct loop.
- Update the Spawn action to support both synchronous mode (block until result signal, current behavior preserved) and async mode (return immediately, check results via Status action later).

## Capabilities

### New Capabilities

- `subagent-signal-communication`: Subagents communicate with the main agent through structured Jido signals instead of synchronous request/response.

### Modified Capabilities

- `subagent-spawn`: Spawn action uses `Directive.SpawnAgent` internally. Gains an optional `async` parameter. Synchronous mode remains the default for backwards compatibility.
- `subagent-status-reporting`: Status action can now return progress messages from active subagents (not just metadata).

## Impact

- **New files**: `lib/goodwizard/plugins/subagent_router.ex`, `lib/goodwizard/actions/subagent/emit_progress.ex`
- **Modified files**: `lib/goodwizard/actions/subagent/spawn.ex` (switch to SpawnAgent directive, add `async` param), `lib/goodwizard/sub_agent.ex` (add `emit_progress` to tools, handle `__parent__` state), `lib/goodwizard/agent.ex` (add SubagentRouter plugin)
- **Dependencies**: None new — uses existing Jido signal/directive primitives

## Prerequisites

- `subagent-configurable-spawn`
