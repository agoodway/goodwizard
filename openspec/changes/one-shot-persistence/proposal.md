## Why

One-shot scheduled tasks are lost on application restart because they use `:timer.apply_after` (in-memory only). Cron jobs already survive restarts via `CronStore` + `CronLoader`, but one-shot jobs scheduled minutes or hours into the future silently vanish if the BEAM shuts down. This creates an unreliable user experience — the agent confirms scheduling, but the task never fires.

## What Changes

- Add file-backed persistence for one-shot scheduled tasks, mirroring the cron persistence model
- Persist each one-shot job as a JSON file under `workspace/scheduling/oneshot/`
- On startup, reload persisted one-shot jobs and re-schedule them with adjusted remaining delay
- Auto-cleanup: delete the persisted file after the one-shot fires (or if `fires_at` is in the past on reload)
- Add a `cancel_oneshot` action so users can cancel pending one-shot tasks before they fire
- Add a `list_oneshot_jobs` action for visibility into pending one-shot tasks

## Capabilities

### New Capabilities

- `oneshot-persistence`: File-backed store, startup loader, and auto-cleanup for one-shot scheduled tasks
- `oneshot-management`: Cancel and list pending one-shot tasks

### Modified Capabilities

_(none — no existing spec-level requirements change)_

## Impact

- **New files**: `OneShotStore`, `OneShotLoader`, `CancelOneShot` action, `ListOneShotJobs` action
- **Modified files**: `OneShot` action (add persistence after scheduling), `application.ex` (call loader on startup), `agent.ex` (register new actions in tools list)
- **Workspace**: New directory `scheduling/oneshot/` created on first save
- **Dependencies**: None new — reuses existing `Jason`, `File`, `:timer` primitives
