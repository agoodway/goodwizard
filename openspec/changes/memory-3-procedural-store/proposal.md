## Why

Goodwizard has no mechanism for learning and retaining behavioral patterns. When the agent discovers an effective approach to a type of task — a deployment workflow, a debugging strategy, a user preference — that knowledge exists only in the conversation session and is lost when the session ends. The next time a similar situation arises, the agent starts from scratch.

Procedural memory — learned behavioral patterns and workflows — gives the agent the ability to accumulate expertise over time. Each procedure captures when to apply it, what steps to follow, and how confident the agent is in it. Confidence adjusts automatically based on usage outcomes: successful applications strengthen a procedure, failures weaken it.

This is **proposal 3 of 9** in the memory system series. It creates the `Memory.Procedural` module providing CRUD, recall scoring, and usage tracking for procedural memory files.

## What Changes

- Create `Goodwizard.Memory.Procedural` module with full CRUD operations (create, read, update, list, delete) for procedural memory entries
- Add a scored recall function that ranks procedures by relevance to a given situation using tag matching, text relevance, confidence level, and recency
- Add usage tracking that records successful and failed applications of a procedure and automatically adjusts its confidence level based on outcome history
- Define the procedure frontmatter schema: id, created_at, updated_at, type, summary, tags, confidence, source, usage_count, success_count, failure_count, last_used
- Define the procedure body convention: When to apply, Steps, Notes sections

## Capabilities

### New Capabilities

- `procedural-memory-store`: File-based CRUD, recall scoring, and usage tracking for procedural memory entries. Procedures are stored as individual markdown files in `memory/procedural/` with YAML frontmatter metadata. Supports scored recall that ranks procedures by tag match, text relevance, confidence, and recency. Usage tracking automatically adjusts confidence levels based on outcome history.

### Modified Capabilities

_None._

## Impact

- **lib/goodwizard/memory/procedural.ex** (new) — core CRUD + recall + usage tracking module
- **test/goodwizard/memory/procedural_test.exs** (new) — unit tests
- **Dependencies**: Uses `Memory.Entry` for parsing/serialization, `Memory.Paths` for path construction, `Brain.Id` for UUID7 generation
- **Existing code**: No modifications to existing modules — purely additive
- **Filesystem**: Reads and writes `.md` files in the `memory/procedural/` directory

## Prerequisites

- `memory-1-entry-parser` — provides `Memory.Entry` (parser/serializer) and `Memory.Paths` (procedural path helpers)
