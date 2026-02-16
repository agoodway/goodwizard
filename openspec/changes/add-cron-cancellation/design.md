## Context

Cron jobs can be scheduled via `Goodwizard.Actions.Scheduling.Cron`, which emits a `Directive.Cron` for Jido's in-memory SchedEx scheduler. Once scheduled, a job runs until the agent process restarts — there is no way for the agent (or user) to cancel or even list active jobs. The underlying infrastructure already supports cancellation: Jido provides `Directive.CronCancel` and the `AgentServer` handles it by looking up the job PID and calling `Jido.Scheduler.cancel/1`. The `AgentServer` also maintains a `cron_jobs` map in its state that tracks all active jobs. Goodwizard simply doesn't expose either capability as agent actions.

## Goals / Non-Goals

**Goals:**

- Cancel a scheduled cron job by `job_id` via the existing `Directive.CronCancel` mechanism
- List all active cron jobs for the current agent (schedule, task, room_id, job_id) by reading `AgentServer` state
- Register both new actions in `Goodwizard.Agent` tools list so the LLM can discover and invoke them
- Accept job_id as either atom or string (convert to atom internally, since Jido uses atom job_ids)

**Non-Goals:**

- Pause/resume individual cron jobs without cancelling them
- Modify a cron job's schedule in place (cancel + re-create is sufficient)
- Persistent job storage (covered by the separate `persist-cron-jobs` change)
- Job execution history or audit log
- Bulk cancel / cancel-all operations

## Decisions

### 1. Two separate actions rather than one combined action

**Choice**: Create `Goodwizard.Actions.Scheduling.CancelCron` and `Goodwizard.Actions.Scheduling.ListCronJobs` as independent actions.

**Rationale**: Each action has a single responsibility and a distinct schema. The LLM can use them independently — listing without cancelling (informational query) or cancelling without listing (when the user already knows the job_id). This follows the same pattern as the existing filesystem actions where each operation is its own module.

**Alternative considered**: A single `ManageCron` action with a `command` parameter (`list` / `cancel`). Rejected because polymorphic actions make tool descriptions harder for the LLM to parse, and the schemas differ (cancel needs `job_id`, list needs no params).

### 2. Read cron_jobs from AgentServer state via Jido.AgentServer API

**Choice**: `ListCronJobs` calls `Jido.AgentServer.state/1` (or the appropriate public API) to read the `cron_jobs` map from the server's process state.

**Rationale**: The `AgentServer` is the single source of truth for which cron jobs are currently running. Reading directly from its state avoids maintaining a shadow copy that could drift.

**Alternative considered**: Maintain a separate list in the agent's strategy state that the cron action updates on schedule/cancel. Rejected because it introduces synchronization complexity and a second source of truth.

### 3. CancelCron emits Directive.CronCancel with job_id

**Choice**: The cancel action builds and returns a `Directive.CronCancel` struct, letting Jido's directive processing handle the actual cancellation (looking up the scheduler PID, calling cancel, removing from state).

**Rationale**: This follows the same directive-based pattern as the existing `Cron` action. The action stays stateless — it transforms input into a cancellation instruction. Jido handles the side effects.

### 4. Job ID format: accept atom or string, normalize to atom

**Choice**: The `job_id` schema field accepts a string. The action converts it to an atom internally using `String.to_existing_atom/1` with a fallback to `String.to_atom/1`, since job_ids are atoms like `:cron_12345678`.

**Rationale**: LLMs and JSON payloads naturally produce strings. The existing cron action generates atom job_ids. Converting at the boundary keeps the API ergonomic while matching Jido's internal representation.

## Risks / Trade-offs

- **AgentServer API for reading cron_jobs may not exist as a public function** -- The `cron_jobs` map is internal `AgentServer` state. If no public accessor exists, we may need to call `GenServer.call(agent_pid, :get_state)` or add a thin helper. This is a minor implementation detail, not an architectural risk.
- **Race condition between list and cancel** -- A job could fire (or be cancelled by another path) between calling `list_cron_jobs` and `cancel_cron_job`. This is acceptable because `CronCancel` is idempotent — cancelling a job that no longer exists is a no-op in Jido's scheduler.
- **Atom exhaustion from job_id conversion** -- Using `String.to_atom/1` on user-provided strings risks atom table exhaustion if called with arbitrary values. Mitigated by the fact that valid job_ids follow the `cron_<integer>` pattern and the LLM will only pass values returned by `list_cron_jobs`. A future hardening step could validate the format before conversion.
