## Context

Goodwizard's agent (Phase 4) maintains in-memory conversation history via the Session skill but loses all state on process restart. ContextBuilder (Phase 3) already accepts a `:memory` option for injecting long-term context into the system prompt. Phase 6 adds a two-layer memory system (long-term knowledge + searchable history) and JSONL session persistence so the agent retains continuity across sessions.

The reference implementation is nanobot's Python codebase: `memory.py` (31-line MemoryStore), `session/manager.py` (lines 61-203 for JSONL persistence), and `loop.py` (lines 366-425 for LLM-driven consolidation).

## Goals / Non-Goals

**Goals:**
- `Goodwizard.Skills.Memory` Jido Skill that loads MEMORY.md from workspace on mount
- Five memory actions: ReadLongTerm, WriteLongTerm, AppendHistory, SearchHistory, Consolidate
- JSONL session persistence in `~/.goodwizard/sessions/` (load on start, save after each turn)
- LLM-driven consolidation that summarizes old messages into HISTORY.md and updates MEMORY.md
- Memory content included in system prompt via ContextBuilder's existing `:memory` option
- Consolidation triggered automatically when message count exceeds `memory_window` (default 50)

**Non-Goals:**
- Vector embeddings or semantic search — plain text search on HISTORY.md is sufficient
- Multi-session management UI — one active session per agent instance
- Memory sharing across agents — each agent has its own workspace memory
- Compression or archival of old JSONL files
- Custom memory schemas beyond MEMORY.md/HISTORY.md

## Decisions

### 1. Memory as a Jido Skill (not standalone GenServer)

**Choice:** `Goodwizard.Skills.Memory` using `use Jido.Skill` with `state_key: :memory`.

**Why:** Follows the Session skill pattern from Phase 4. Memory state lives inside the agent process — no extra process, no message passing. The Skill's `mount/2` resolves the memory directory and loads MEMORY.md content into state. ContextBuilder reads from the skill state, keeping data flow simple.

**Alternative considered:** Separate GenServer for memory management — rejected because memory is per-agent and doesn't need independent lifecycle.

### 2. Five discrete actions over a single CRUD action

**Choice:** Separate action modules under `Goodwizard.Actions.Memory.*` for each operation.

**Why:** Each operation has a distinct schema, distinct side effects, and maps to a distinct tool the LLM can call. ReadLongTerm is read-only. WriteLongTerm mutates MEMORY.md. AppendHistory is append-only to HISTORY.md. SearchHistory is read-only with a pattern parameter. Consolidate orchestrates LLM calls. Collapsing these into one action with a `mode` parameter would make tool descriptions unclear to the LLM.

**Alternative considered:** Single `MemoryAction` with operation parameter — rejected because it reduces tool discoverability for the LLM and complicates schema validation.

### 3. JSONL format for session persistence

**Choice:** One JSONL file per session. First line is metadata (session key, created_at, version), subsequent lines are individual messages.

**Why:** JSONL is append-friendly — saving after each turn is a single line append, not a full file rewrite. It's human-readable for debugging. The nanobot reference uses this exact format. Parsing is straightforward with `File.stream!/1` and `Jason.decode!/1`.

**Alternative considered:** SQLite — rejected as overkill for sequential message storage. ETS/DETS — rejected because JSONL is portable and inspectable.

### 4. Consolidation as an action (not automatic background process)

**Choice:** `Consolidate` is a Jido Action triggered by `on_before_cmd/2` when message count exceeds `memory_window`. It runs synchronously before the ReAct cycle.

**Why:** Consolidation must complete before the next turn to ensure the trimmed message history is used. Running it as a background process would create race conditions with the active conversation. Triggering in `on_before_cmd` means it happens transparently before each turn, only when needed.

**Alternative considered:** GenServer timer-based consolidation — rejected because timing-based triggers could fire mid-conversation and create consistency issues.

### 5. Session persistence hooks in on_after_cmd

**Choice:** Save session to JSONL in `on_after_cmd/3`, load in agent start (or `mount/2` of Session skill).

**Why:** `on_after_cmd` fires after each completed turn, which is the natural save point. Loading happens once at agent start. This keeps persistence logic in the lifecycle hooks without adding new processes.

**Alternative considered:** Save on every `add_message` call — rejected because it would double the writes per turn (user + assistant) with no benefit since partial turns aren't useful to persist.

## Risks / Trade-offs

**[Consolidation adds latency to turns that trigger it]** → Only fires when messages exceed `memory_window` (default 50), so it's infrequent. The LLM call for consolidation is one-shot with a focused prompt. Expected ~2-3s overhead for consolidation turns, acceptable for an interactive assistant.

**[JSONL files grow unbounded]** → Acceptable for Phase 6. A single conversation's JSONL file is small (typical messages are <1KB). File rotation/cleanup can be added later if needed.

**[LLM consolidation quality depends on prompt engineering]** → Port the nanobot consolidation prompt which is already tested. The prompt asks for structured JSON output with `history_entry` and `memory_update` fields, which is reliable with modern models.

**[Race condition if agent crashes between consolidation and session save]** → Memory files (MEMORY.md, HISTORY.md) are written during consolidation. Session JSONL is written in on_after_cmd. If crash happens between, worst case is the session has stale messages but memory files are up to date. Next consolidation will re-process the gap. Acceptable for Phase 6.

**[File.stream! for SearchHistory may be slow on large HISTORY.md]** → HISTORY.md grows by one line per consolidation (~every 50 messages). Even after 1000 conversations, it's a few thousand lines. Stream + filter is fine at this scale.
