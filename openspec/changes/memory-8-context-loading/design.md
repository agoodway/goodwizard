## Context

Goodwizard's memory system (after proposals 1-7) stores three types of long-term memory:

- **Semantic** (MEMORY.md + brain entities) -- already loaded into the system prompt by the memory plugin
- **Episodic** (`memory/episodic/*.md`) -- structured records of past experiences, searchable by tags/type/text
- **Procedural** (`memory/procedural/*.md`) -- learned procedures with confidence levels, searchable by situation/tags

The semantic profile (MEMORY.md) is already injected into the system prompt at session start. Episodic and procedural memories are only accessed when the agent explicitly calls search/recall actions mid-conversation. This means the agent starts every conversation without awareness of past experiences or learned procedures.

Channel handlers (CLI in `lib/goodwizard/channels/cli.ex`, Telegram in `lib/goodwizard/channels/telegram.ex`) manage the conversation lifecycle and know when a new session begins. They are the natural integration point for loading memory context.

## Goals / Non-Goals

**Goals:**

- Relevant episodic memories are automatically surfaced at conversation start
- Relevant procedural memories are automatically surfaced at conversation start
- The first user message serves as a topic signal for relevance-based memory retrieval
- Memory context is formatted as readable text appended to the system prompt
- Loading is fast (file reads only, no LLM calls) and graceful on failure
- The amount of loaded context is bounded to avoid inflating the system prompt

**Non-Goals:**

- No mid-conversation memory reloading -- context is loaded once at session start
- No LLM-based relevance ranking -- use the existing file-based search/recall scoring from `Memory.Episodic` and `Memory.Procedural`
- No modification to the MEMORY.md loading path (handled by the existing memory plugin)
- No user-facing configuration for memory context loading (hardcoded defaults are sufficient for now)
- No streaming or lazy loading -- all context is loaded synchronously before the first LLM call

## Decisions

### 1. Load context via a Jido Action, not inline in the channel handler

Create a `LoadMemoryContext` action that encapsulates the memory loading logic. The channel handler calls this action and uses its output to augment the system prompt.

**Why over alternatives:**
- *Inline in channel handler* -- Mixes memory logic with channel concerns. Harder to test. Duplicates logic across CLI and Telegram handlers.
- *Jido plugin mount callback* -- Plugins mount before any messages arrive, so there is no topic signal available. Would only load recent memories without relevance filtering.
- *Jido directive* -- Over-engineering for a single synchronous read operation.

### 2. Always load recent episodes plus topic-relevant episodes

The action always loads the N most recent episodes (default 3) regardless of topic. If the first message provides a topic, additional topic-relevant episodes are loaded via text search. The two sets are deduplicated and capped at `max_episodes` (default 5).

**Why:** Recent episodes provide continuity ("we were working on X yesterday"). Topic-relevant episodes provide task-specific context ("last time we tried this approach and it failed"). Both are valuable.

### 3. Load procedures via recall scoring when topic is available, fallback to most-used

When a topic is provided, use `Memory.Procedural.recall/3` which scores by tag match, text relevance, confidence, and recency. When no topic is available, fall back to listing the highest-confidence, most-used procedures.

**Why over alternatives:**
- *Always load all procedures* -- Too much context. Procedures can accumulate quickly.
- *Only load when topic matches* -- Misses high-value general procedures (like "always check tests before committing") that apply broadly.

### 4. Format as markdown sections in the system prompt

The memory context is formatted as two markdown sections: "Relevant Past Experiences" and "Relevant Procedures". Each episode is a compact summary (timestamp, type, outcome, one-line summary, key lesson). Each procedure is a compact block (summary, confidence, when-to-apply).

**Why:** Markdown is the format used throughout the system prompt. Compact formatting keeps token usage low while providing enough context for the LLM to act on.

### 5. Inject context by appending to the system prompt, not as a separate message

The loaded memory context is appended to the system prompt text (after the preamble and MEMORY.md content). This keeps it in the system role where the LLM treats it as persistent context rather than conversational content.

**Why over alternatives:**
- *Separate system message* -- Some providers do not support multiple system messages. Single system message is more portable.
- *User message* -- The LLM may interpret memory context as user input and respond to it directly.
- *Assistant message* -- Confuses the conversation flow.

### 6. Graceful degradation on failure

If memory loading fails (empty stores, file read errors, action errors), the channel handler proceeds without memory context. No error is shown to the user. A debug log is emitted.

**Why:** Memory context is an enhancement, not a requirement. A conversation should never fail to start because memory loading broke.

## Risks / Trade-offs

- **System prompt inflation** -- Loading too many episodes and procedures increases the system prompt size and reduces the context budget available for conversation. Mitigated by strict limits (5 episodes, 3 procedures) and compact formatting. Can be tuned later via config if needed.

- **Irrelevant context when topic matching is weak** -- The first message may be a greeting ("hi") with no topic signal, leading to procedure recall based on most-used rather than relevance. Acceptable since most-used procedures are likely the most broadly useful.

- **Cold start with empty memory stores** -- New installations have no episodes or procedures to load. The action handles empty stores gracefully by returning empty context. The system prompt is not affected.

- **First-message latency** -- Memory loading adds synchronous file reads before the first LLM call. With reasonable file counts (<200 episodes, <50 procedures), this should be sub-100ms. If stores grow very large, this becomes an argument for Phase 5 lifecycle management (proposal 9).
