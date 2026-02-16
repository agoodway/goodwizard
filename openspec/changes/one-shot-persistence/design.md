## Context

One-shot scheduled tasks use `:timer.apply_after` which is purely in-memory. If the BEAM restarts between scheduling and firing, the task is silently lost. Cron jobs already have a proven persistence model (`CronStore` + `CronLoader` + `CronRegistry`) that writes one JSON file per job under `workspace/scheduling/cron/` and reloads them on startup. One-shot persistence follows the same architecture.

The key difference from cron: one-shot jobs have a finite `fires_at` timestamp and must be auto-cleaned after firing (or discarded if expired on reload).

## Goals / Non-Goals

**Goals:**

- Persist one-shot jobs to disk so they survive application restarts
- Reload pending one-shot jobs on startup with adjusted remaining delay
- Auto-delete the persisted file after the job fires
- Provide cancel and list actions for pending one-shot jobs
- Mirror the cron persistence architecture (CronStore pattern) for consistency

**Non-Goals:**

- Guaranteed exactly-once delivery — `:timer.apply_after` is best-effort and a restart near `fires_at` may miss the window
- Retry logic for expired jobs — if `fires_at` is in the past on reload, the job is discarded (not re-fired)
- Database-backed persistence — files remain the storage layer
- Distributed coordination — single-node only, same as cron

## Decisions

### 1. File-per-job storage under `workspace/scheduling/oneshot/`

**Choice:** One JSON file per job, named `<job_id>.json`, mirroring CronStore.

**Rationale:** Proven pattern already in production. No file-level locking needed. Atomic create/delete. Consistent directory structure under `scheduling/`.

**Alternatives considered:**
- Single manifest file — rejected because of read-modify-write race risk and cron already uses file-per-job
- SQLite — rejected because it adds a dependency for a simple key-value use case

### 2. Auto-cleanup via wrapper around deliver/2

**Choice:** Wrap the existing `OneShot.deliver/2` callback to delete the persisted file after dispatching the signal.

**Rationale:** The cleanup is co-located with firing — no separate GC process needed. If deletion fails, the expired job is discarded on next reload anyway (fires_at in the past).

### 3. Expired jobs discarded on reload (not re-fired)

**Choice:** If `fires_at` is in the past when the loader runs, delete the file and skip the job.

**Rationale:** One-shot tasks are time-sensitive. A "send daily report at 9am" that fires at 2pm is worse than not firing at all. The agent can be informed via a log warning. Re-firing expired tasks would require a separate "missed task" recovery policy that's out of scope.

### 4. Reuse OneShotStore (new module) parallel to CronStore

**Choice:** Create `Goodwizard.Scheduling.OneShotStore` with the same API shape as `CronStore` (`save/1`, `delete/1`, `list/0`, `load_all/0`).

**Rationale:** Consistent API. Same path-traversal validation. Same JSON encoding. Could be refactored into a shared base later but not worth the abstraction now.

### 5. OneShotLoader runs after CronLoader in startup sequence

**Choice:** Call `OneShotLoader.reload/0` from `Application.start_optional_channels/0` right after `reload_cron_jobs()`.

**Rationale:** Same startup phase, same pattern. One-shot reload doesn't need an agent — it just calls `:timer.apply_after` directly, so it's simpler than CronLoader.

### 6. Job ID format: `oneshot_<16hex>`

**Choice:** SHA256 hash of `{fires_at, task, room_id}`, take first 16 hex chars, prefix with `oneshot_`.

**Rationale:** Deterministic — scheduling the same task twice produces the same ID (last-write-wins, idempotent). Distinct prefix from `cron_` avoids cross-store collisions.

## Risks / Trade-offs

**[Risk] Timer drift on reload** — If the app restarts 5 minutes before `fires_at`, the reloaded timer fires at approximately the right time (within seconds). For delays of hours this is acceptable.
→ Mitigation: Use `DateTime.diff(fires_at, now, :millisecond)` for precise remaining delay.

**[Risk] Orphaned files if deliver callback crashes** — The file would persist and be reloaded, but `fires_at` would be in the past.
→ Mitigation: Loader discards expired jobs and deletes their files.

**[Risk] Atom table growth from job_id atoms** — Each one-shot job creates an atom (`:oneshot_<hash>`).
→ Mitigation: Same risk as cron (which already creates atoms). One-shot jobs are typically low-volume. The `String.to_existing_atom` pattern is used in cancel to avoid unbounded creation.
