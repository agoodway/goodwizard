## 1. Schema Extension

- [x] 1.1 Add `mode` parameter to `Goodwizard.Actions.Scheduling.ScheduledTask` schema — type string, optional, default `"main"`, allowed values `"main"` or `"isolated"`
- [x] 1.2 Add `model` parameter to `Goodwizard.Actions.Scheduling.ScheduledTask` schema — type string, optional, no default
- [x] 1.3 Update action description to document the new `mode` and `model` parameters

## 2. Message Format

- [x] 2.1 Include `mode` in the cron message payload (`%{type: "scheduled_task.task", task: ..., room_id: ..., mode: ...}`)
- [x] 2.2 Conditionally include `model` in the payload only when `mode` is `"isolated"` and `model` is provided
- [x] 2.3 Update `job_id` hash to include `mode` so that the same task scheduled in different modes gets distinct job IDs

## 3. Signal Handler

- [x] 3.1 Update the cron tick signal handler to read `mode` from the message payload
- [x] 3.2 When `mode` is `"main"` (or absent), dispatch inline through the main agent pipeline (existing behavior)
- [x] 3.3 When `mode` is `"isolated"`, delegate to the isolated cron runner (new module)

## 4. Child Agent Lifecycle

- [x] 4.1 Create `Goodwizard.Actions.Scheduling.ScheduledTaskRunner` module with `run_isolated/3` function (accepts task, room_id, opts including model)
- [x] 4.2 Spawn a `Goodwizard.SubAgent` (or CronAgent variant) via `Goodwizard.Jido.start_agent`, passing model override if provided
- [x] 4.3 Send task as query via `ask_sync`, await response with timeout
- [x] 4.4 Save agent response to target Messaging room via `Goodwizard.Messaging`
- [x] 4.5 Stop the child agent process in an `after` block (cleanup on both success and failure)
- [x] 4.6 Add concurrency check before spawning — skip tick and log warning if at limit

## 5. Tests

- [x] 5.1 Test scheduled task action with `mode: "main"` produces correct message payload (backwards compatible)
- [x] 5.2 Test scheduled task action with `mode: "isolated"` includes mode in message payload
- [x] 5.3 Test scheduled task action with `mode: "isolated"` and `model` includes model in message payload
- [x] 5.4 Test scheduled task action with `mode: "main"` and `model` excludes model from message payload
- [x] 5.5 Test scheduled task action with invalid `mode` value returns schema validation error
- [x] 5.6 Test scheduled task action without `mode` defaults to `"main"` behavior
- [x] 5.7 Test `ScheduledTaskRunner.run_isolated/3` spawns child agent and returns result
- [x] 5.8 Test `ScheduledTaskRunner.run_isolated/3` with model override configures child agent correctly
- [x] 5.9 Test `ScheduledTaskRunner.run_isolated/3` cleans up child agent on failure
- [x] 5.10 Test concurrency limit prevents spawning when at capacity
