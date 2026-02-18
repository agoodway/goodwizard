## Context

Scheduled tasks are currently scheduled via `Goodwizard.Actions.Scheduling.ScheduledTask`, which emits a `Directive.Cron` for Jido's in-memory SchedEx scheduler. No state is written to disk — jobs exist only in the running BEAM process. The project already has a file-backed entity store (Brain) that uses YAML frontmatter markdown files under the workspace directory, and a Nebulex ETS cache for hot-path reads.

## Goals / Non-Goals

**Goals:**

- Persist every scheduled task to disk so it survives agent restarts
- Reload and re-register all persisted jobs on agent startup
- Remove the persisted file when a job is cancelled
- Provide a `list_scheduled_tasks` action for introspection
- Follow existing workspace conventions (file-per-entity, workspace-relative paths)

**Non-Goals:**

- Distributed or multi-node job coordination
- Job execution history or audit log
- Cron expression editing (cancel + re-create is sufficient)
- Database-backed storage — files are the persistence layer

## Decisions

### 1. File-per-job in `workspace/scheduling/scheduled_tasks/`

Each scheduled task is saved as a JSON file named by its `job_id` (e.g., `scheduled_task_12345.json`). JSON is chosen over YAML frontmatter markdown because scheduled tasks are pure structured data with no freeform body content — markdown adds no value here.

**Alternative considered**: Single `scheduled_task_jobs.json` manifest file. Rejected because concurrent writes from multiple actions would require file-level locking, and individual files allow atomic create/delete without read-modify-write cycles.

**Alternative considered**: Reuse Brain entity store. Rejected because scheduled tasks are not knowledge entities — they're scheduling metadata. Mixing them into the brain directory would conflate concerns.

### 2. Store module with simple CRUD

A new `Goodwizard.Scheduling.ScheduledTaskStore` module provides `save/1`, `delete/1`, `list/0`, and `load_all/0`. It reads the workspace path from `Goodwizard.Config.workspace()` and manages the `scheduling/scheduled_tasks/` subdirectory.

### 3. Save happens inside the existing Scheduled task action

After `Directive.cron/3` is built and validation passes, the action calls `ScheduledTaskStore.save/1` before returning. This keeps persistence co-located with scheduling — no separate GenServer or process needed.

### 4. Reload on application startup

`Goodwizard.Application` calls a `Goodwizard.Scheduling.ScheduledTaskLoader.reload/0` function after the Jido agent is started. This reads all persisted jobs via `ScheduledTaskStore.load_all/0` and re-emits `Directive.Cron` for each one through the agent.

### 5. Cancel action deletes the file

A new `cancel_scheduled_task` action accepts a `job_id`, calls `ScheduledTaskStore.delete/1` to remove the file, and emits a `Directive.CronCancel` to stop the in-memory scheduler.

## Risks / Trade-offs

- **Stale jobs on disk**: If the agent crashes between emitting a directive and saving the file, the job runs in-memory but isn't persisted. This is acceptable — the window is tiny, and on restart the job simply won't be reloaded. The user can re-schedule it.
- **No file locking**: Two concurrent scheduled task actions with the same `job_id` could race. Mitigated by the deterministic `job_id` derivation (phash2 of schedule+task+room_id) — same inputs always produce the same file, so the last write wins with identical content.
- **Startup ordering**: Reload must happen after the Jido agent is started and ready to accept directives. If the agent isn't ready, directives will be lost. Mitigated by calling reload from a Task started after the agent supervisor child.
