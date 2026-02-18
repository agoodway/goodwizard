## Context

Goodwizard currently supports recurring task scheduling through `Goodwizard.Actions.Scheduling.ScheduledTask`, which validates a cron expression and emits a `Directive.Cron` for Jido's SchedEx-based scheduler. This handles "every day at 9am" patterns well, but there is no way to schedule a single-fire task — "remind me in 20 minutes" or "send the report at 3pm today" cannot be expressed as cron. Users must either schedule a recurring job and manually cancel it, or hope the agent's context window survives long enough.

Jido's directive system already provides `Directive.Schedule`, which accepts a `delay_ms` and a `message` and delivers the message to the agent after the delay. The infrastructure exists — Goodwizard just doesn't expose it. The existing cron signal pipeline processes `%{type: "scheduled_task.task"}` messages via CronTick, so a one-time task can reuse the same payload format and flow through the same handling path without changes to signal routing.

## Goals / Non-Goals

**Goals:**

- Schedule a one-time task by relative delay (N minutes from now)
- Schedule a one-time task at a specific wall-clock time (ISO 8601 datetime)
- Reuse the existing CronTick-compatible message format so the signal pipeline handles one-time tasks identically to recurring scheduled tasks
- Register the new action in the agent's tools list

**Non-Goals:**

- Persistence across restarts (addressed by the separate `persist-cron-jobs` change)
- Recurring schedules (already handled by the existing Scheduled task action)
- UI for managing scheduled tasks
- Sub-minute precision or real-time guarantees
- Timezone-aware scheduling for the `at` mode (accepts UTC ISO 8601 only in v1)

## Decisions

### 1. Single action with mode detection vs two separate actions

The action accepts either `delay_minutes` or `at`, but not both. A single action with mutually exclusive parameters is chosen over two separate actions (`ScheduleDelay` / `ScheduleAt`) because:

- The LLM sees one tool instead of two, reducing tool selection ambiguity
- The underlying behavior is identical — both compute a `delay_ms` and emit `Directive.Schedule`
- Validation ensures exactly one mode is active per call

**Alternative considered**: Two separate actions. Rejected because the implementation difference is a single conditional branch, and two tools with nearly identical descriptions would confuse the LLM's tool selection.

### 2. Reuse CronTick message format

The one-time task message payload uses the same `%{type: "scheduled_task.task", task: task, room_id: room_id}` shape as the recurring scheduled task action. This means the existing signal handling pipeline routes scheduled task messages to the appropriate room without modification.

**Alternative considered**: A new `%{type: "one_time.task", ...}` message type. Rejected because it would require adding a new signal handler branch with identical behavior. The "scheduled_tasks" naming is slightly misleading for a one-time task, but the payload shape is what matters for routing, not the type string.

### 3. Use `Directive.Schedule` with computed delay

Both modes ultimately produce a `Directive.Schedule{delay_ms: ms, message: payload}`:

- **Delay mode**: `delay_ms = delay_minutes * 60_000`
- **At mode**: `delay_ms = DateTime.diff(at, now, :millisecond)`. If delta is negative (time in the past), the action returns an error.

This leverages the existing Jido runtime's `Process.send_after/3` mechanism. No new directive types or scheduler integrations are needed.

### 4. Job ID derivation

A deterministic job ID is computed as `:"one_time_#{:erlang.phash2({task, room_id, scheduled_at})}"` where `scheduled_at` is the computed fire time. This provides a stable identifier for logging and potential future cancellation support, while avoiding collisions with scheduled task IDs (which use the `scheduled_task_` prefix).

## Risks / Trade-offs

- **In-memory only**: Like the current scheduled task action, one-time task schedules are backed by `Process.send_after` and lost on restart. The `persist-cron-jobs` change can be extended to cover one-time tasks in the future.
- **Clock drift for long delays**: `Process.send_after` uses monotonic time, so it won't drift, but if the system hibernates or the BEAM suspends, the timer may fire late. This is acceptable for a personal assistant — precision beyond "roughly when requested" is not critical.
- **Past-time rejection in `at` mode**: The action rejects times in the past rather than firing immediately. This is a deliberate safety choice — if the user says "at 2pm" and it's already 3pm, it's better to surface the error than silently execute. The user can retry with `delay_minutes: 0` if they want immediate execution (though `delay_minutes` must be positive, so the minimum is 1 minute).
- **No cancellation**: Unlike cron (which has `CronCancel`), there is no `ScheduleCancel` in Jido for `Process.send_after` timers. Once a one-time task is scheduled, it will fire. Cancellation support would require storing the timer reference, which is out of scope for this change.
