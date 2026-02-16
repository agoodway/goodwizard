## Why

The cron action only supports recurring schedules via cron expressions. There is no way to schedule a one-shot task at a specific time — "remind me in 20 minutes" or "send the report at 3pm today" cannot be expressed as a cron pattern. Users must either schedule a recurring job and manually cancel it after the first run, or rely on the agent's context window staying alive long enough — neither of which is practical.

Jido already provides `Directive.Schedule` (delay-based) and `Directive.Cron` (recurring), but Goodwizard only exposes the cron variant. A one-shot scheduling action would let the agent fire a task after a delay or at a specific wall-clock time, then clean up automatically.

## What Changes

- Add a new `Goodwizard.Actions.Scheduling.OneShot` action with two modes:
  - **Delay mode** (`delay_minutes`): Schedule a task N minutes from now. Emits a `Directive.Schedule` with the computed `delay_ms`.
  - **At mode** (`at`): Schedule a task at a specific ISO 8601 datetime. Computes the delta from now and emits a `Directive.Schedule`. Rejects times in the past.
- The action creates a `CronTick`-compatible message payload so the existing signal handling pipeline processes it identically to recurring cron tasks.
- Register the new action in `Goodwizard.Agent` tools list.

## Capabilities

### New Capabilities

- `oneshot-scheduling`: Schedule a single-fire task by delay or wall-clock time, delivered to a Messaging room via the existing cron signal pipeline

### Modified Capabilities

_None — the existing cron action is unchanged. This is a new, parallel action._

## Impact

- **New files**: `lib/goodwizard/actions/scheduling/one_shot.ex`
- **Modified files**: `lib/goodwizard/agent.ex` (add to tools list)
- **Dependencies**: None new — uses existing `Directive.Schedule` from Jido and `DateTime` from stdlib
- **Limitation**: Like cron, one-shot jobs are in-memory only. If the agent restarts before the timer fires, the job is lost. This can be addressed later by the `persist-cron-jobs` change.
