## Context

Cron jobs are currently scheduled via `Goodwizard.Actions.Scheduling.Cron`, which emits a `Directive.Cron` for Jido's in-memory SchedEx scheduler. No state is written to disk — jobs exist only in the running BEAM process. The project already has a file-backed entity store (Brain) that uses YAML frontmatter markdown files under the workspace directory, and a Nebulex ETS cache for hot-path reads.

## Goals / Non-Goals

**Goals:**

- Persist every cron job to disk so it survives agent restarts
- Reload and re-register all persisted jobs on agent startup
- Remove the persisted file when a job is cancelled
- Provide a `list_cron_jobs` action for introspection
- Follow existing workspace conventions (file-per-entity, workspace-relative paths)

**Non-Goals:**

- Distributed or multi-node job coordination
- Job execution history or audit log
- Cron expression editing (cancel + re-create is sufficient)
- Database-backed storage — files are the persistence layer

## Decisions

### 1. File-per-job in `workspace/scheduling/cron/`

Each cron job is saved as a JSON file named by its `job_id` (e.g., `cron_12345.json`). JSON is chosen over YAML frontmatter markdown because cron jobs are pure structured data with no freeform body content — markdown adds no value here.

**Alternative considered**: Single `cron_jobs.json` manifest file. Rejected because concurrent writes from multiple actions would require file-level locking, and individual files allow atomic create/delete without read-modify-write cycles.

**Alternative considered**: Reuse Brain entity store. Rejected because cron jobs are not knowledge entities — they're scheduling metadata. Mixing them into the brain directory would conflate concerns.

### 2. Store module with simple CRUD

A new `Goodwizard.Scheduling.CronStore` module provides `save/1`, `delete/1`, `list/0`, and `load_all/0`. It reads the workspace path from `Goodwizard.Config.workspace()` and manages the `scheduling/cron/` subdirectory.

### 3. Save happens inside the existing Cron action

After `Directive.cron/3` is built and validation passes, the action calls `CronStore.save/1` before returning. This keeps persistence co-located with scheduling — no separate GenServer or process needed.

### 4. Reload on application startup

`Goodwizard.Application` calls a `Goodwizard.Scheduling.CronLoader.reload/0` function after the Jido agent is started. This reads all persisted jobs via `CronStore.load_all/0` and re-emits `Directive.Cron` for each one through the agent.

### 5. Cancel action deletes the file

A new `cancel_cron_task` action accepts a `job_id`, calls `CronStore.delete/1` to remove the file, and emits a `Directive.CronCancel` to stop the in-memory scheduler.

## Risks / Trade-offs

- **Stale jobs on disk**: If the agent crashes between emitting a directive and saving the file, the job runs in-memory but isn't persisted. This is acceptable — the window is tiny, and on restart the job simply won't be reloaded. The user can re-schedule it.
- **No file locking**: Two concurrent cron actions with the same `job_id` could race. Mitigated by the deterministic `job_id` derivation (phash2 of schedule+task+room_id) — same inputs always produce the same file, so the last write wins with identical content.
- **Startup ordering**: Reload must happen after the Jido agent is started and ready to accept directives. If the agent isn't ready, directives will be lost. Mitigated by calling reload from a Task started after the agent supervisor child.
