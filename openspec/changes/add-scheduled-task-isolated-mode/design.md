## Context

All scheduled tasks currently execute through the main agent's ReAct pipeline. When a cron tick fires, the scheduler delivers a `%{type: "scheduled_task.task", task: ..., room_id: ...}` message to the main `Goodwizard.Agent`. The agent processes it inline — same context window, same model, same conversation history as interactive sessions. This means a weekly deep-analysis job competes for tokens with live conversation, and there is no way to run a scheduled task with a cheaper or stronger model.

Jido provides `Directive.SpawnAgent` for launching child agents with full parent-child hierarchy tracking. Goodwizard already uses a similar pattern via `Goodwizard.SubAgent` and the `spawn_subagent` action, which starts a child `ReActAgent` under `Goodwizard.Jido`, runs a query, and cleans up on completion.

Combining scheduled task scheduling with child agent spawning would allow scheduled tasks to run in isolated agent instances — separate context, configurable model, no interference with the main conversation.

## Goals / Non-Goals

**Goals:**
- Allow scheduled scheduled tasks to execute in an isolated child agent instead of the main agent's pipeline
- Support an optional model override for isolated-mode tasks (e.g. use a cheaper model for routine checks, a stronger model for deep analysis)
- Deliver isolated agent responses to the same target Messaging room as main-mode tasks
- Track child agents via Jido's parent-child hierarchy and clean up on completion

**Non-Goals:**
- Inter-agent communication between the main agent and isolated scheduled-task agents
- Shared memory or conversation history between main and child agents
- Persistent child agents that outlive a single cron tick execution
- Retry or failure recovery for isolated cron executions (can be added later)
- Dynamic model validation against a provider registry

## Decisions

### 1. Extend existing scheduled task action schema vs. create a new action

**Decision**: Add optional `mode` and `model` parameters to the existing `Goodwizard.Actions.Scheduling.ScheduledTask` action rather than creating a separate `ScheduleIsolatedCronTask` action.

**Rationale**: The scheduling concern is the same — validate a cron expression and emit a directive. The difference is only in how the tick is dispatched. A single action with a mode switch is simpler for the LLM to discover and use and avoids tool sprawl. The default is `"isolated"` — scheduled tasks should run in their own context by default to avoid polluting the main conversation.

**Alternatives considered**: A dedicated `schedule_isolated_scheduled_task_task` action was considered but rejected because it would duplicate all the cron validation logic and require the LLM to choose between two nearly identical tools.

### 2. Include mode/model in the cron message payload

**Decision**: The `message` map stored in the `Directive.cron` call will include `mode` and `model` fields alongside the existing `type`, `task`, and `room_id`. The signal handler reads these fields to decide dispatch strategy.

**Rationale**: The message payload is the only data that survives from scheduling time to execution time. The signal handler needs to know the mode at tick time, not at schedule time. Including it in the payload keeps the directive stateless and self-describing.

### 3. Isolated dispatch via SubAgent pattern, not Directive.SpawnAgent

**Decision**: On cron tick with `mode: "isolated"`, the signal handler will spawn a `Goodwizard.SubAgent` (or a new `CronAgent` variant) using the same `Goodwizard.Jido.start_agent` / `ask_sync` / `stop_agent` pattern used by `Goodwizard.Actions.Subagent.Spawn`. If a `model` override is provided, it will be passed to the child agent's configuration.

**Rationale**: The existing `SubAgent` spawn pattern is proven and handles the full lifecycle (start, query, await, cleanup). Using `Directive.SpawnAgent` would require hooking into the directive processing pipeline, which adds complexity. The signal handler already runs in a context where it can start processes directly.

**Alternatives considered**: Emitting a `Directive.SpawnAgent` from the scheduled task action was considered but rejected because the directive would need to carry the task query and model override, which doesn't fit the current directive schema cleanly. Direct spawning in the signal handler is more straightforward.

### 4. Child agent lifecycle: spawn on tick, complete, cleanup

**Decision**: Each isolated cron tick spawns a fresh child agent, sends the task as a query, awaits the response (with a timeout), saves the response to the target Messaging room, and then stops the agent process. No state persists between ticks.

**Rationale**: Scheduled tasks are independent executions. A fresh agent per tick means no context leakage between runs, no stale state, and predictable resource usage. This mirrors how the existing `spawn_subagent` action works.

### 5. Model override applies only in isolated mode

**Decision**: The `model` parameter is accepted in the action schema but only used when `mode: "isolated"`. When `mode: "main"`, the `model` parameter is ignored silently (no error, no warning).

**Rationale**: In main mode, the task runs through the main agent which already has its model configured. Overriding the main agent's model for a single cron tick would require changing agent configuration mid-conversation, which is not supported. Silent ignore (rather than error) keeps the API simple when switching between modes.

## Risks / Trade-offs

**Isolated agents lack main conversation context** — By design, isolated scheduled-task agents have no access to the main agent's conversation history, active session, or in-progress state. They do share the same workspace, so brain data and filesystem are accessible. This is the intended trade-off: isolation provides independence at the cost of context.

**Spawning overhead per tick** — Each isolated cron tick starts a new agent process, which includes character hydration and tool registration. For high-frequency schedules (e.g. every minute), this could be noticeable. Mitigation: the existing high-frequency warning in the scheduled task action applies equally to isolated mode.

**Model parameter validation** — The `model` parameter is passed as a string (e.g. `"anthropic:claude-haiku-4-5"`) with no validation against available models. An invalid model string will cause the child agent to fail at LLM call time, not at schedule time. Mitigation: the error will surface in the Messaging room response and in logs.

**Concurrent isolated agents** — Multiple isolated scheduled tasks firing simultaneously could exceed the existing `@max_concurrent_subagents` limit in the spawn action. The cron runner should respect a similar concurrency limit or share the same pool. Mitigation: implement a concurrency check in the signal handler before spawning.
