## Why

The heartbeat currently reads HEARTBEAT.md as a single blob and dispatches it as one message to the agent. There is no way to define multiple independent checks — "check my inbox", "review calendar for upcoming events", "run project health check" — and have them batched into a single heartbeat cycle. Users must either cram everything into one natural-language paragraph (hoping the agent handles all of it) or accept that only one concern can be addressed per tick.

A structured heartbeat format would let users define a checklist of awareness tasks. The heartbeat would parse them and present them to the agent as a structured prompt, ensuring each check gets attention. This also enables per-item tracking — the agent can report on each check individually, and future enhancements could skip items that haven't changed.

## What Changes

- Define a structured format for HEARTBEAT.md using markdown task-list syntax:
  ```markdown
  - [ ] Check inbox for new messages
  - [ ] Review calendar for events in the next 2 hours
  - [ ] Run project health check on goodwizard
  ```
- The heartbeat GenServer parses the file into individual check items when it detects task-list format. Falls back to current single-blob behavior for plain text (backwards compatible).
- The dispatched prompt wraps parsed items in a structured instruction: "Process each of the following awareness checks and report on each one: 1. Check inbox... 2. Review calendar..."
- Add a `checks` field to the heartbeat Messaging payload so responses can be correlated to specific checks.
- Add a new `Goodwizard.Actions.Heartbeat.UpdateChecks` action so the agent can add, remove, or replace checks in HEARTBEAT.md programmatically (like how `schedule_cron_task` manages cron jobs).
- Update `TOOLS.md` in the workspace bootstrap files with guidance on when to use heartbeat vs cron, so the agent can make smart routing decisions.

## Capabilities

### New Capabilities

- `heartbeat-batching`: Parse HEARTBEAT.md task-list items into individual awareness checks, dispatch as a structured multi-check prompt, and track per-check results
- `update-heartbeat-checks`: Agent action to add, remove, or list checks in HEARTBEAT.md without manual file editing
- `scheduling-guidance`: System prompt guidance in TOOLS.md explaining when to use heartbeat (batched, context-aware, low-overhead) vs cron (exact timing, isolated, model override)

### Modified Capabilities

- `heartbeat`: Extended to support structured task-list format in addition to plain text. Plain text behavior unchanged.

## Impact

- **Modified files**: `lib/goodwizard/heartbeat.ex` (add parsing logic, structured prompt generation)
- **New files**:
  - `lib/goodwizard/heartbeat/parser.ex` — task-list detection and extraction
  - `lib/goodwizard/actions/heartbeat/update_checks.ex` — action for managing heartbeat checks
- **Modified workspace files**: `priv/workspace/TOOLS.md` — add heartbeat vs cron decision guidance
- **Modified files**: `lib/goodwizard/agent.ex` (add UpdateChecks to tools list)
- **Backwards compatible**: Plain text HEARTBEAT.md files continue to work exactly as before. Structured format is opt-in via markdown task-list syntax.
- **Dependencies**: None — markdown task-list parsing is simple regex/string splitting
