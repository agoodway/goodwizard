## Why

Scheduled tasks scheduled through the `schedule_scheduled_task` action exist only in-memory via Jido's SchedEx scheduler. When the agent restarts, all scheduled jobs are lost with no way to recover them. Users must manually re-schedule every recurring task after each restart, which defeats the purpose of a persistent assistant.

## What Changes

- Add a file-backed scheduled task store that persists scheduled jobs to the workspace
- Save each scheduled task to disk when created via the `schedule_scheduled_task` action
- Reload and re-register all persisted jobs on agent startup
- Support removing persisted jobs when cancelled
- Add a `list_scheduled_tasks` action to show all scheduled jobs

## Capabilities

### New Capabilities

- `cron-persistence`: File-backed storage and lifecycle management for scheduled tasks — save on create, delete on cancel, reload on startup, and list active jobs

### Modified Capabilities

_None — the existing scheduled task action's interface stays the same. Persistence is additive._

## Impact

- **New files**: Cron store module, list action, startup loader
- **Modified files**: `Actions.Scheduling.Cron` (save after scheduling), `Application` or agent init (reload on startup)
- **Workspace**: New `scheduling/scheduled_tasks/` directory under the workspace for job files
- **Dependencies**: None — uses existing YAML frontmatter entity pattern and workspace conventions
