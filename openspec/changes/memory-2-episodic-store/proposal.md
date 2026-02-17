## Why

Goodwizard currently has no structured record of past experiences. The only history mechanism is `HISTORY.md`, a flat append-only log with no filtering, search, or structured metadata. When the agent encounters a situation similar to a past interaction, it has no efficient way to recall what happened, what was tried, and what worked or failed.

Episodic memory — structured records of notable past experiences — gives the agent the ability to learn from its history. Each episode captures the situation, approach taken, result, and lessons learned, tagged with type and outcome metadata for efficient retrieval.

This is **proposal 2 of 9** in the memory system series. It creates the `Memory.Episodic` module providing CRUD and search operations for episodic memory files.

## What Changes

- Create `Goodwizard.Memory.Episodic` module with core CRUD operations (create, read, list, delete) for episodic memory entries
- Add text-based search across episode frontmatter and body content with filtering by type, outcome, tags, and date range
- Define the episode frontmatter schema: id, timestamp, type, summary, tags, outcome, entities_involved
- Define the episode body convention: Observation, Approach, Result, Lessons sections

## Capabilities

### New Capabilities

- `episodic-memory-store`: File-based CRUD and search for episodic memory entries. Episodes are stored as individual markdown files in `memory/episodic/` with YAML frontmatter metadata. Supports filtering by type, outcome, tags, and date range, plus full-text search across frontmatter and body.

### Modified Capabilities

_None._

## Impact

- **lib/goodwizard/memory/episodic.ex** (new) — core CRUD + search module
- **test/goodwizard/memory/episodic_test.exs** (new) — unit tests
- **Dependencies**: Uses `Memory.Entry` for parsing/serialization, `Memory.Paths` for path construction, `Brain.Id` for UUID7 generation
- **Existing code**: No modifications to existing modules — purely additive
- **Filesystem**: Reads and writes `.md` files in the `memory/episodic/` directory

## Prerequisites

- `memory-1-entry-parser` — provides `Memory.Entry` (parser/serializer) and `Memory.Paths` (episodic path helpers)
