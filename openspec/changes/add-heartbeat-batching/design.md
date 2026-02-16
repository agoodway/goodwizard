## Context

The heartbeat GenServer (`Goodwizard.Heartbeat`) reads `HEARTBEAT.md` from the workspace on a configurable schedule, detects changes via mtime, and dispatches the file contents as a single message to the agent via `GoodwizardAgent.ask_sync/3`. The response is saved to a Messaging room alongside the original prompt.

Today the entire file is sent as one opaque blob. Users who want the agent to check multiple independent concerns (inbox, calendar, project health) must pack everything into one paragraph and hope the agent addresses each one. There is no way to enumerate discrete checks, no structured prompt wrapping, and no per-check tracking in the message payload.

## Goals / Non-Goals

**Goals:**
- Parse HEARTBEAT.md task-list syntax (`- [ ] <text>`) into individual check items
- Generate a structured numbered-instruction prompt from parsed checks so the agent addresses each one
- Add a `checks` metadata field to the heartbeat Messaging payload for per-check correlation
- Maintain full backwards compatibility: plain text HEARTBEAT.md files dispatch exactly as they do today

**Non-Goals:**
- Per-check scheduling (all checks run on the same heartbeat tick)
- Check dependencies or ordering constraints
- Check-level caching or skip-if-unchanged logic
- Parsing checked items (`- [x] ...`) differently from unchecked (`- [ ] ...`) at this stage
- UI or channel-specific rendering of individual checks

## Decisions

### Decision 1: Detection via regex line matching

**Choice**: Lines matching the pattern `~r/^- \[([ x])\] (.+)$/m` trigger structured mode. If ANY line in the file matches, the entire file is parsed in structured mode.

**Rationale**: Markdown task-list syntax is unambiguous and widely understood. The "any match" rule avoids a confusing partial-parsing mode where some lines are checks and others are ignored. Users who mix prose with task-list items clearly intend structured behavior.

**Alternatives considered**:
- Frontmatter flag (`format: tasklist`): More explicit but adds ceremony to a file meant to be simple. Detection from content is zero-config.
- Majority rule (>50% lines are task-list): Fragile and confusing threshold behavior.

### Decision 2: Extract parser to `Goodwizard.Heartbeat.Parser`

**Choice**: Create a dedicated `Goodwizard.Heartbeat.Parser` module with pure functions for detection, extraction, and prompt formatting.

**Rationale**: The parser has no side effects and benefits from direct unit testing. Keeping it separate from the GenServer follows the same pattern as `Goodwizard.Brain` extracting parsing logic into helper modules. The GenServer calls the parser; the parser knows nothing about GenServer state.

### Decision 3: Structured prompt uses numbered instruction format

**Choice**: Parsed checks are formatted as a numbered list with a preamble instruction:

```
Process each of the following awareness checks and report on each:
1. Check inbox for new messages
2. Review calendar for events in the next 2 hours
3. Run project health check on goodwizard
```

**Rationale**: Numbered lists with explicit "report on each" instruction produce more reliable per-item responses from LLMs than bullet points or raw text. The preamble sets the expectation that all items need attention.

### Decision 4: Checks metadata on the message, not in content

**Choice**: Add `checks: [%{index: 1, text: "Check inbox"}, ...]` to the message metadata map passed to `Messaging.save_message/1`, rather than embedding structured data in the message `content` field.

**Rationale**: The `content` field is the human/agent-readable text. Metadata is the right place for machine-readable correlation data. This keeps existing Messaging display logic untouched and allows future enhancements (per-check status tracking, response extraction) to operate on metadata without parsing content strings.

### Decision 5: Dedicated action for managing heartbeat checks

**Choice**: Create `Goodwizard.Actions.Heartbeat.UpdateChecks` with three operations: `add` (append a check), `remove` (remove by text match), and `list` (return current checks). The action reads/writes HEARTBEAT.md directly using the same parser.

**Rationale**: Without a dedicated action, the agent must use generic `WriteFile`/`EditFile` tools to modify HEARTBEAT.md, which requires it to understand the file format and handle edge cases (empty file, creating the file, preserving existing checks). A purpose-built action mirrors the pattern established by `schedule_cron_task` — the agent calls a semantic tool ("add inbox check to my heartbeat") rather than doing file surgery. The parser module is already being created for the GenServer, so the action reuses it.

**Alternatives considered**: Relying on existing filesystem tools was considered but rejected — the agent needs to know the file path, the checkbox syntax, and handle atomicity. A dedicated action encapsulates all of this.

### Decision 6: System prompt guidance for heartbeat vs cron in TOOLS.md

**Choice**: Add a "Scheduling & Monitoring" section to `priv/workspace/TOOLS.md` that explains when to use heartbeat (batched periodic checks with main-session context) vs cron (exact timing, isolated execution, model override). This gets injected into the system prompt via the existing `inject_bootstrap_files` pipeline.

**Rationale**: The agent has access to both heartbeat and cron tools but no guidance on which to choose. Without explicit routing guidance, the agent will default to whichever tool it sees first or make inconsistent choices. TOOLS.md is already a bootstrap file loaded every turn — it's the canonical place for tool usage instructions. The guidance covers:

- **Heartbeat**: Multiple periodic checks, context-aware decisions, conversational continuity, low-overhead monitoring
- **Cron**: Exact timing, standalone tasks, model override, one-shot reminders, noisy/frequent tasks

## Risks / Trade-offs

- **Mixed format files** — A file with some task-list lines and some prose lines is treated as structured, with only the task-list lines extracted as checks. The prose lines are silently dropped from the prompt. This is an intentional simplification: users should use either all task-list or all prose. If this causes confusion, a future change could include non-check prose as context in the preamble.
- **Agent may not address all checks** — The structured prompt asks the agent to address each check, but there is no enforcement. The agent may merge checks, skip some, or address them out of order. This is acceptable: the structured format improves the odds of comprehensive coverage but does not guarantee it.
- **Checked vs unchecked items** — Both `- [ ]` and `- [x]` lines are parsed as checks. A future enhancement could use the checked state to skip completed items, but for now all items are dispatched every tick.
- **TOOLS.md size** — Adding scheduling guidance increases the system prompt size. The guidance is concise (~30 lines) and high-value for routing decisions. Bootstrap files are capped at 1MB so this is well within limits.
- **UpdateChecks file contention** — The action writes to the same HEARTBEAT.md that the GenServer reads. The GenServer uses mtime-based change detection, so a write from the action will trigger a re-read on the next tick. This is the desired behavior — adding a check should take effect on the next heartbeat cycle.
