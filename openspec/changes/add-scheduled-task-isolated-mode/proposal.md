## Why

All scheduled tasks currently execute through the main agent's ReAct pipeline. This means a weekly deep-analysis job or a daily report competes for the same context window, token budget, and model as interactive conversation. There is no way to run a scheduled task with a different model (e.g. a cheaper model for routine checks, a stronger model for deep analysis) or in a separate agent process that won't pollute the main session's conversation history.

Jido provides `Directive.SpawnAgent` for launching child agents with full hierarchy tracking. Combining this with scheduled task scheduling would allow scheduled tasks to run in isolated agent instances — separate context, configurable model, no interference with the main conversation.

## What Changes

- Add an optional `mode` parameter to the existing `schedule_scheduled_task` action:
  - `"isolated"` (default): On each cron tick, spawn a child `GoodwizardAgent` via `Directive.SpawnAgent`, send the task as its query, and let it complete independently. The child has its own context window and session.
  - `"main"`: Legacy behavior — cron tick is delivered to the main agent via signal.
- Add an optional `model` parameter (only used in isolated mode) to override the model for the spawned agent. Defaults to the main agent's model if not specified.
- The isolated agent's response is saved to the target Messaging room, same as main-mode scheduled tasks.
- Child agents are tracked via Jido's parent-child hierarchy and cleaned up on completion.

## Capabilities

### New Capabilities

- `cron-isolated-mode`: Run scheduled tasks in a dedicated child agent with optional model override, separate context window, and automatic cleanup

### Modified Capabilities

- `schedule_scheduled_task`: Extended with `mode` and `model` optional parameters. Default changes to `"isolated"` — existing schedules without an explicit mode will now run in isolated child agents.

## Impact

- **Modified files**: `lib/goodwizard/actions/scheduling/scheduled_tasks.ex` (add mode/model params, isolated dispatch logic)
- **New files**: Possibly a `lib/goodwizard/actions/scheduling/scheduled_tasks_runner.ex` module to handle isolated-mode child agent lifecycle, depending on complexity
- **Dependencies**: Uses existing `Directive.SpawnAgent` and `Directive.Cron` from Jido — no new deps
- **Signal handling**: The agent's cron tick handler needs to branch on mode — main-mode dispatches inline, isolated-mode spawns a child agent and forwards the task
- **Trade-off**: Isolated agents don't have access to the main agent's conversation history or in-progress session state. This is by design — isolation means independence. Brain and workspace data are still accessible since both agents share the same workspace.
