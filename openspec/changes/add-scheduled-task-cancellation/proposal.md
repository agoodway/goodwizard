## Why

The agent can schedule scheduled tasks via `schedule_scheduled_task` but has no way to cancel them. Once scheduled, a job runs until the agent process restarts. If a user says "stop checking my inbox" or "cancel the daily report", the agent has no action to call. The underlying infrastructure already supports cancellation — Jido provides `Directive.CronCancel` and the `AgentServer` handles it by looking up the job PID and calling `Jido.Scheduler.cancel/1` — but Goodwizard doesn't expose it.

## What Changes

- Add a new `Goodwizard.Actions.Scheduling.CancelScheduledTask` action that emits a `Directive.CronCancel` for a given `job_id`.
- Add a new `Goodwizard.Actions.Scheduling.ListScheduledTasks` action that returns all active scheduled tasks for the current agent (reads from `AgentServer` state's `scheduled_task_jobs` map).
- Register both actions in `Goodwizard.Agent` tools list.

The LLM workflow becomes:
1. User: "Cancel the daily report"
2. Agent calls `list_scheduled_tasks` to find the matching job_id
3. Agent calls `cancel_scheduled_task` with the job_id
4. Jido's `CronCancel` directive handler stops the scheduler and removes the job from state

## Capabilities

### New Capabilities

- `cron-cancellation`: Cancel a scheduled scheduled task by job_id via `Directive.CronCancel`
- `cron-listing`: List all active scheduled tasks with their schedule, task description, and job_id

### Modified Capabilities

_None — the existing schedule action is unchanged._

## Impact

- **New files**: `lib/goodwizard/actions/scheduling/cancel_cron.ex`, `lib/goodwizard/actions/scheduling/list_scheduled_tasks.ex`
- **Modified files**: `lib/goodwizard/agent.ex` (add both to tools list)
- **Dependencies**: None new — uses existing `Directive.CronCancel` from Jido
- **Agent state access**: `ListScheduledTasks` needs to read `scheduled_task_jobs` from the `AgentServer` state. This may require a new helper or API on `Jido.AgentServer` to expose the scheduled_task_jobs map, since it's server-side state not directly accessible from action context. Alternative: maintain a shadow list in the agent's strategy state that the scheduled task action updates on schedule/cancel.
