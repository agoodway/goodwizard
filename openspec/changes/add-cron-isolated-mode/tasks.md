## 1. Schema Extension

- [ ] 1.1 Add `mode` parameter to `Goodwizard.Actions.Scheduling.Cron` schema — type string, optional, default `"main"`, allowed values `"main"` or `"isolated"`
- [ ] 1.2 Add `model` parameter to `Goodwizard.Actions.Scheduling.Cron` schema — type string, optional, no default
- [ ] 1.3 Update action description to document the new `mode` and `model` parameters

## 2. Message Format

- [ ] 2.1 Include `mode` in the cron message payload (`%{type: "cron.task", task: ..., room_id: ..., mode: ...}`)
- [ ] 2.2 Conditionally include `model` in the payload only when `mode` is `"isolated"` and `model` is provided
- [ ] 2.3 Update `job_id` hash to include `mode` so that the same task scheduled in different modes gets distinct job IDs

## 3. Signal Handler

- [ ] 3.1 Update the cron tick signal handler to read `mode` from the message payload
- [ ] 3.2 When `mode` is `"main"` (or absent), dispatch inline through the main agent pipeline (existing behavior)
- [ ] 3.3 When `mode` is `"isolated"`, delegate to the isolated cron runner (new module)

## 4. Child Agent Lifecycle

- [ ] 4.1 Create `Goodwizard.Actions.Scheduling.CronRunner` module with `run_isolated/3` function (accepts task, room_id, opts including model)
- [ ] 4.2 Spawn a `Goodwizard.SubAgent` (or CronAgent variant) via `Goodwizard.Jido.start_agent`, passing model override if provided
- [ ] 4.3 Send task as query via `ask_sync`, await response with timeout
- [ ] 4.4 Save agent response to target Messaging room via `Goodwizard.Messaging`
- [ ] 4.5 Stop the child agent process in an `after` block (cleanup on both success and failure)
- [ ] 4.6 Add concurrency check before spawning — skip tick and log warning if at limit

## 5. Tests

- [ ] 5.1 Test cron action with `mode: "main"` produces correct message payload (backwards compatible)
- [ ] 5.2 Test cron action with `mode: "isolated"` includes mode in message payload
- [ ] 5.3 Test cron action with `mode: "isolated"` and `model` includes model in message payload
- [ ] 5.4 Test cron action with `mode: "main"` and `model` excludes model from message payload
- [ ] 5.5 Test cron action with invalid `mode` value returns schema validation error
- [ ] 5.6 Test cron action without `mode` defaults to `"main"` behavior
- [ ] 5.7 Test `CronRunner.run_isolated/3` spawns child agent and returns result
- [ ] 5.8 Test `CronRunner.run_isolated/3` with model override configures child agent correctly
- [ ] 5.9 Test `CronRunner.run_isolated/3` cleans up child agent on failure
- [ ] 5.10 Test concurrency limit prevents spawning when at capacity
