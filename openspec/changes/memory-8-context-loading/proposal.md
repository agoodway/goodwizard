## Why

Goodwizard has episodic and procedural memory stores (proposals 1-6) and enhanced consolidation that populates them (proposal 7), but none of this accumulated experience is surfaced at conversation start. Every new conversation begins with a blank slate beyond the semantic profile in MEMORY.md. The agent has no awareness of recent interactions, past mistakes, or learned procedures unless the user explicitly asks it to search memories.

For the three-memory architecture to deliver value, relevant memories need to be loaded automatically when a conversation begins. A user returning to continue a multi-day project should see the agent recall what happened last time. A user hitting a recurring problem should benefit from procedures the agent learned previously.

This is proposal 8 of 9 in the memory system series. See `docs/memory-system-plan.md` (Phase 4, sections 4.1 and 4.2) for the full architecture context.

## What Changes

- **Create `LoadMemoryContext` action** (`lib/goodwizard/actions/memory/load_context.ex`) that loads relevant episodic and procedural memories based on recency and topic relevance
- **Format loaded memories as context text** suitable for prepending to the system prompt
- **Integrate into channel handlers** (CLI and Telegram) to call `LoadMemoryContext` on the first message of a new session and inject the result into the system prompt context
- The action combines recent episodes (always loaded) with topic-relevant episodes and procedures (loaded when the first message provides a topic signal)

## Capabilities

### New Capabilities

- `context-loading`: Automatic loading of relevant episodic and procedural memories at conversation start, formatted as system prompt context

### Modified Capabilities

_(none -- channel handler integration is a new call site, not a modification of existing specs)_

## Impact

- **`lib/goodwizard/actions/memory/load_context.ex`** (new) -- The `LoadMemoryContext` action
- **`lib/goodwizard/channels/cli.ex`** -- Add memory context loading on first message of a session
- **`lib/goodwizard/channels/telegram.ex`** -- Add memory context loading on first message of a session
- **Dependencies**: Requires `Memory.Episodic` and `Memory.Procedural` modules from proposals 1-6
- **No new dependencies** -- uses existing memory store modules
- **Performance**: Adds one synchronous operation at conversation start (file reads, no LLM call)

## Prerequisites

- `memory-5-episodic-actions` -- Episodic memory store and search must exist
- `memory-6-procedural-actions` -- Procedural memory store and recall must exist
