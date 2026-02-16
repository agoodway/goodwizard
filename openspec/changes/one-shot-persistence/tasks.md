## 1. OneShotStore

- [ ] 1.1 Create `lib/goodwizard/scheduling/oneshot_store.ex` with `save/1`, `delete/1`, `list/0`, `load_all/0` — mirrors CronStore API but reads/writes under `workspace/scheduling/oneshot/`
- [ ] 1.2 Add path-traversal validation for job IDs (reject `..`, `/`, null bytes, >255 bytes)
- [ ] 1.3 Create `test/goodwizard/scheduling/oneshot_store_test.exs` — save, delete, list, path traversal rejection, malformed JSON handling

## 2. OneShotRegistry

- [ ] 2.1 Extend `CronRegistry` (or create `OneShotRegistry`) to track `:timer` references keyed by `oneshot_*` job IDs, with `register/2`, `lookup/1`, `cancel/1`, and auto-cleanup on fire
- [ ] 2.2 Create `test/goodwizard/scheduling/oneshot_registry_test.exs` — register, lookup, cancel, cleanup after fire

## 3. OneShot Action Persistence

- [ ] 3.1 Modify `lib/goodwizard/actions/scheduling/one_shot.ex` to generate deterministic job IDs via SHA256 of `{fires_at, task, room_id}` with `oneshot_` prefix
- [ ] 3.2 Add `OneShotStore.save/1` call after `:timer.apply_after` succeeds — persist `job_id`, `task`, `room_id`, `fires_at`, `created_at`
- [ ] 3.3 Register timer reference in OneShotRegistry after scheduling
- [ ] 3.4 Modify `deliver/2` to delete persisted file via `OneShotStore.delete/1` and deregister from OneShotRegistry after signal dispatch
- [ ] 3.5 Update `test/goodwizard/actions/scheduling/one_shot_test.exs` — verify file persistence on schedule, file cleanup on fire, expired job handling

## 4. OneShotLoader

- [ ] 4.1 Create `lib/goodwizard/scheduling/oneshot_loader.ex` with `reload/0` — loads all persisted jobs, discards expired (fires_at in past), re-schedules pending with adjusted delay
- [ ] 4.2 Add `OneShotLoader.reload/0` call in `application.ex` `start_optional_channels/0` after `reload_cron_jobs()`
- [ ] 4.3 Create `test/goodwizard/scheduling/oneshot_loader_test.exs` — reload pending jobs, discard expired, skip malformed files

## 5. Management Actions

- [ ] 5.1 Create `lib/goodwizard/actions/scheduling/cancel_oneshot.ex` — cancels timer via registry, deletes persisted file, idempotent on missing jobs
- [ ] 5.2 Create `lib/goodwizard/actions/scheduling/list_oneshot_jobs.ex` — returns all persisted jobs sorted by `fires_at` ascending
- [ ] 5.3 Register `CancelOneShot` and `ListOneShotJobs` in `agent.ex` tools list
- [ ] 5.4 Create `test/goodwizard/actions/scheduling/cancel_oneshot_test.exs` — cancel pending, cancel already-fired, invalid job_id
- [ ] 5.5 Create `test/goodwizard/actions/scheduling/list_oneshot_jobs_test.exs` — list with jobs, list empty, sort order
