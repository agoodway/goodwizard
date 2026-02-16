## Why

Cron jobs scheduled through the `schedule_cron_task` action exist only in-memory via Jido's SchedEx scheduler. When the agent restarts, all scheduled jobs are lost with no way to recover them. Users must manually re-schedule every recurring task after each restart, which defeats the purpose of a persistent assistant.

## What Changes

- Add a file-backed cron job store that persists scheduled jobs to the workspace
- Save each cron job to disk when created via the `schedule_cron_task` action
- Reload and re-register all persisted jobs on agent startup
- Support removing persisted jobs when cancelled
- Add a `list_cron_jobs` action to show all scheduled jobs

## Capabilities

### New Capabilities

- `cron-persistence`: File-backed storage and lifecycle management for cron jobs — save on create, delete on cancel, reload on startup, and list active jobs

### Modified Capabilities

_None — the existing cron action's interface stays the same. Persistence is additive._

## Impact

- **New files**: Cron store module, list action, startup loader
- **Modified files**: `Actions.Scheduling.Cron` (save after scheduling), `Application` or agent init (reload on startup)
- **Workspace**: New `scheduling/cron/` directory under the workspace for job files
- **Dependencies**: None — uses existing YAML frontmatter entity pattern and workspace conventions
