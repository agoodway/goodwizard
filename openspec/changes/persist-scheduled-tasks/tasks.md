## 1. Scheduled Task Store

- [x] 1.1 Create `Goodwizard.Scheduling.ScheduledTaskStore` module with `save/1`, `delete/1`, `list/0`, and `load_all/0` functions that read/write JSON files in `workspace/scheduling/scheduled_tasks/`
- [x] 1.2 Ensure `save/1` creates the `scheduling/scheduled_tasks/` directory if it doesn't exist
- [x] 1.3 Add unit tests for ScheduledTaskStore: save, delete, list, load_all, malformed file handling

## 2. Persist on Schedule

- [x] 2.1 Modify `Goodwizard.Actions.Scheduling.ScheduledTask` to call `ScheduledTaskStore.save/1` after successful validation and directive creation
- [x] 2.2 Include `created_at` timestamp in the persisted job record
- [x] 2.3 Add test verifying a file is written after scheduling and not written on validation failure

## 3. Cancel Action

- [x] 3.1 Create `Goodwizard.Actions.Scheduling.ScheduledTaskCancel` action that accepts `job_id`, calls `ScheduledTaskStore.delete/1`, and emits `Directive.CronCancel`
- [x] 3.2 Handle unknown `job_id` gracefully (still emit cancel directive, return success)
- [x] 3.3 Add tests for cancel with existing job and unknown job_id

## 4. List Action

- [x] 4.1 Create `Goodwizard.Actions.Scheduling.ScheduledTaskList` action that calls `ScheduledTaskStore.list/0` and returns job records
- [x] 4.2 Add tests for list with jobs and empty directory

## 5. Startup Reload

- [x] 5.1 Create `Goodwizard.Scheduling.ScheduledTaskLoader` module with `reload/1` that reads all persisted jobs and re-emits `Directive.Cron` for each
- [x] 5.2 Log warnings for malformed files and skip them without crashing
- [x] 5.3 Call `ScheduledTaskLoader.reload/1` from `Goodwizard.Application` after the Jido agent is started
- [x] 5.4 Add tests for reload with valid jobs, empty directory, and malformed files
