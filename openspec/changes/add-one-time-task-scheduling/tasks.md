## 1. Core Action

- [x] 1.1 Create `lib/goodwizard/actions/scheduling/one_time.ex` with `use Jido.Action`, name `schedule_one_time_task`, and schema defining `delay_minutes` (optional positive integer), `at` (optional string), `task` (required string), and `room_id` (required string)
- [x] 1.2 Implement mutual exclusivity validation: exactly one of `delay_minutes` or `at` must be provided, return error if both or neither are present
- [x] 1.3 Implement delay mode: validate `delay_minutes` is a positive integer, compute `delay_ms = delay_minutes * 60_000`
- [x] 1.4 Implement at mode: parse ISO 8601 datetime from `at`, compute delta from `DateTime.utc_now()`, reject past times with descriptive error
- [x] 1.5 Derive deterministic job ID using `:"one_time_#{:erlang.phash2({task, room_id, fire_at})}"`

## 2. Signal Compatibility

- [x] 2.1 Build CronTick-compatible message payload `%{type: "scheduled_task.task", task: task, room_id: room_id}` in the action's `run/2`
- [x] 2.2 Emit `Directive.Schedule` with computed `delay_ms` and the CronTick-compatible message
- [x] 2.3 Return `{:ok, result_map, [directive]}` with result containing `scheduled: true`, `task`, `room_id`, `job_id`, `fires_at`, and mode (`delay` or `at`)

## 3. Agent Registration

- [x] 3.1 Add `Goodwizard.Actions.Scheduling.OneTime` to the tools list in `Goodwizard.Agent`, adjacent to `Goodwizard.Actions.Scheduling.ScheduledTask`

## 4. Tests

- [x] 4.1 Test delay mode: verify directive emitted with correct `delay_ms` for a given `delay_minutes`
- [x] 4.2 Test delay mode edge cases: zero and negative `delay_minutes` return errors
- [x] 4.3 Test at mode: verify directive emitted with approximately correct `delay_ms` for a future datetime
- [x] 4.4 Test at mode edge cases: past datetime returns error, invalid ISO 8601 string returns error
- [x] 4.5 Test mutual exclusivity: both params provided returns error, neither param provided returns error
- [x] 4.6 Test message payload matches CronTick format `%{type: "scheduled_task.task", task: _, room_id: _}`
