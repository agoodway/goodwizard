## Why

One-shot scheduled tasks are lost on application restart because they use `:timer.apply_after` (in-memory only). Scheduled tasks already survive restarts via `ScheduledTaskStore` + `ScheduledTaskLoader`, but one-time tasks scheduled minutes or hours into the future silently vanish if the BEAM shuts down. This creates an unreliable user experience — the agent confirms scheduling, but the task never fires.

## What Changes

- Add file-backed persistence for one-time tasks, mirroring the scheduled-task persistence model
- Persist each one-time task as a JSON file under `workspace/scheduling/one_time/`
- On startup, reload persisted one-time tasks and re-schedule them with adjusted remaining delay
- Auto-cleanup: delete the persisted file after the one-time task fires (or if `fires_at` is in the past on reload)
- Add a `cancel_one_time` action so users can cancel pending one-time tasks before they fire
- Add a `list_one_time_jobs` action for visibility into pending one-time tasks

## Capabilities

### New Capabilities

- `one_time-persistence`: File-backed store, startup loader, and auto-cleanup for one-time tasks
- `one_time-management`: Cancel and list pending one-time tasks

### Modified Capabilities

_(none — no existing spec-level requirements change)_

## Impact

- **New files**: `OneTimeStore`, `OneTimeLoader`, `CancelOneTime` action, `ListOneTimeJobs` action
- **Modified files**: `OneTime` action (add persistence after scheduling), `application.ex` (call loader on startup), `agent.ex` (register new actions in tools list)
- **Workspace**: New directory `scheduling/one_time/` created on first save
- **Dependencies**: None new — reuses existing `Jason`, `File`, `:timer` primitives
