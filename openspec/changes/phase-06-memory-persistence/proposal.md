# Phase 6: Memory and Session Persistence

## Why

Without memory, every conversation starts from scratch. The two-layer memory system (MEMORY.md for long-term knowledge + HISTORY.md for searchable conversation summaries) gives the agent continuity across sessions. Session persistence ensures conversations survive restarts. This is what makes Goodwizard a personal assistant rather than a stateless chatbot.

## What

### Goodwizard.Skills.Memory (Jido Skill)

Port of `nanobot/agent/memory.py:MemoryStore` expanded into a Jido skill.

- State key: `:memory`
- Schema: memory_dir (string), long_term_content (string)
- On mount: resolve memory dir from workspace, load MEMORY.md content

### Memory Actions

**ReadLongTerm** — Read MEMORY.md content.

**WriteLongTerm** — Write content to MEMORY.md, update skill state.

**AppendHistory** — Append timestamped entry to HISTORY.md.

**SearchHistory** — Search HISTORY.md for a pattern using `File.stream!` + `Enum.filter`.

**Consolidate** — LLM-driven memory consolidation. Port of `_consolidate_memory` (loop.py lines 366-425):
1. Take old messages (everything except recent N)
2. Format as timestamped lines
3. Build consolidation prompt, call LLM for JSON with `history_entry` and `memory_update`
4. Parse JSON, append history entry, update long-term memory if changed
5. Trim session messages to recent N
6. Trigger: when `length(session.messages) > memory_window` (default 50)

### Session Persistence

Update Session skill to persist to JSONL files. Port of `nanobot/session/manager.py:SessionManager` (lines 61-203):

- Session dir: `~/.goodwizard/sessions/`
- Filename: session key with `:` replaced by `_`, `.jsonl` extension
- JSONL format: first line is metadata, rest are messages
- Load on agent creation, save after each turn

### Integration Updates

- Add Memory skill to Agent (as additional skill alongside ReActAgent's built-in skills)
- Register memory actions as additional tools via dynamic tool registration (`react.register_tool` signal)
- Hook consolidation into `on_before_cmd/2`: check message count, trigger if over memory_window
- Include memory content in system prompt via ContextBuilder

## Dependencies

- Phase 4 (Agent Definition)
- Phase 5 (CLI Channel) — for manual testing

## Reference

- `nanobot/agent/memory.py` (31 lines)
- `nanobot/session/manager.py` (lines 61-203)
- `nanobot/agent/loop.py` (lines 366-425 for consolidation)
