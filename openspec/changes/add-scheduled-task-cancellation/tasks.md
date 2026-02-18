## 1. CancelScheduledTask Action

- [x] 1.1 Create `lib/goodwizard/actions/scheduling/cancel_cron.ex` with `use Jido.Action`, name `cancel_scheduled_task`, schema (`job_id` required string), and stub `run/2`
- [x] 1.2 Implement `run/2` — convert string `job_id` to atom, build `Directive.CronCancel` with the atom job_id, return `{:ok, %{cancelled: true, job_id: atom_id}, [directive]}`
- [x] 1.3 Add description string explaining purpose and expected input format for LLM tool discovery

## 2. ListScheduledTasks Action

- [x] 2.1 Create `lib/goodwizard/actions/scheduling/list_scheduled_tasks.ex` with `use Jido.Action`, name `list_scheduled_tasks`, empty schema, and stub `run/2`
- [x] 2.2 Implement `run/2` — read `scheduled_task_jobs` map from `AgentServer` state via `Jido.AgentServer` API (or GenServer.call fallback), transform into list of job descriptor maps with string job_id, schedule, task, room_id
- [x] 2.3 Handle case where `scheduled_task_jobs` is nil or empty — return `{:ok, %{jobs: [], count: 0}}`
- [x] 2.4 Add description string explaining purpose for LLM tool discovery

## 3. Agent Registration

- [x] 3.1 Add `Goodwizard.Actions.Scheduling.CancelScheduledTask` to the `tools:` list in `Goodwizard.Agent`
- [x] 3.2 Add `Goodwizard.Actions.Scheduling.ListScheduledTasks` to the `tools:` list in `Goodwizard.Agent`

## 4. Tests

- [x] 4.1 Create `test/goodwizard/actions/scheduling/cancel_scheduled_task_test.exs` with test setup
- [x] 4.2 Test: valid string job_id is converted to atom and CronCancel directive is emitted
- [x] 4.3 Test: return value includes `cancelled: true` and the atom job_id
- [x] 4.4 Test: nonexistent job_id still returns success (idempotent cancellation)
- [x] 4.5 Create `test/goodwizard/actions/scheduling/list_scheduled_tasks_test.exs` with test setup
- [x] 4.6 Test: returns list of job descriptors when scheduled_task_jobs exist in agent state
- [x] 4.7 Test: returns empty list and count 0 when no scheduled tasks are active
- [x] 4.8 Test: each job descriptor contains job_id (string), schedule, task, and room_id fields
