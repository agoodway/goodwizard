## Context

This is the second change in a 9-proposal series implementing Goodwizard's three-memory architecture (`docs/memory-system-plan.md`). It builds on `memory-1-entry-parser`, which provides `Memory.Entry` for markdown+YAML parsing and `Memory.Paths` for episodic/procedural path helpers.

Episodic memory stores structured records of past experiences — problems solved, errors encountered, decisions made, tasks completed, and general interactions. Each episode is a single markdown file in `memory/episodic/` with YAML frontmatter for metadata and a body with conventional sections (Observation, Approach, Result, Lessons).

The module follows the same design pattern as `Goodwizard.Brain` but is simpler: no JSON Schema validation, no entity references, no relationship traversal. Episodes are immutable after creation (no update operation) — if the understanding of a past event changes, that is a new episode, not an edit.

Key files:
- `lib/goodwizard/memory/entry.ex` — parser/serializer (from proposal 1)
- `lib/goodwizard/memory/paths.ex` — path helpers (from proposal 1)
- `lib/goodwizard/brain/id.ex` — UUID7 generation (existing)
- `lib/goodwizard/memory/episodic.ex` — new module (this proposal)

## Goals / Non-Goals

**Goals:**
- Create, read, list, and delete episodic memory entries as individual markdown files
- Auto-generate UUID7 IDs and ISO 8601 timestamps on creation
- Validate required frontmatter fields (type, summary, outcome) at the module level
- Filter episodes by type, outcome, tags, and date range
- Search episode content by case-insensitive text query across frontmatter and body
- Sort results by timestamp descending (most recent first)
- Enforce configurable result limits

**Non-Goals:**
- Agent-facing Jido actions (see proposal 5: `memory-5-episodic-actions`)
- Episode updates (episodes are immutable records of what happened)
- Semantic/vector search (text substring search is sufficient for the file-based store)
- Archival or lifecycle management (see proposal 9: `memory-9-lifecycle-management`)
- Directory bootstrapping (see proposal 4: `memory-4-bootstrap-and-preamble`)

## Decisions

### 1. Episodes are immutable

No `update/4` function is provided. Episodes record what happened at a point in time. If the agent's understanding changes, that is captured in a new episode or in procedural memory, not by rewriting history.

**Rationale:** Immutability simplifies the module (no merge logic, no `updated_at` tracking) and preserves the integrity of the historical record. The agent can always create a follow-up episode that references an earlier one.

**Alternative considered:** Mutable episodes with `updated_at` timestamps. Rejected because episodic memory in cognitive science is append-only — you form new memories rather than editing old ones.

### 2. Frontmatter validation at module level

`create/3` validates that required fields (`type`, `summary`, `outcome`) are present and that `type` and `outcome` are within their allowed value sets. This happens before writing the file.

**Rationale:** The `Memory.Entry` parser is deliberately schema-free. Field validation belongs in the module that understands the domain (episodic vs. procedural). This keeps the parser reusable while ensuring data integrity.

**Alternative considered:** Validate at the action level only. Rejected because the module is also used directly in consolidation (proposal 7), which bypasses actions.

### 3. Allowed episode types and outcomes

Episode types: `task_completion`, `problem_solved`, `error_encountered`, `decision_made`, `interaction`.

Outcome types: `success`, `failure`, `partial`, `abandoned`.

These are module attributes, not configuration. The set is fixed because the consolidation prompt and recall scoring depend on known categories.

**Rationale:** A fixed taxonomy enables consistent filtering and meaningful aggregation. New types can be added by modifying the module attribute — no migration needed since existing files are unaffected.

### 4. Search implementation is file-scan based

`search/3` scans all `.md` files in `memory/episodic/`, parses frontmatter, applies filters, and optionally searches body text. No indexing.

**Rationale:** The expected volume is low (tens to hundreds of episodes, with archival at 200+). File scanning with frontmatter-only parsing is fast enough. Adding an index would introduce stale-index bugs and complexity that is not justified at this scale.

**Performance concern:** Each search reads all episode files from disk. Mitigation: frontmatter-only parsing (skip body unless text query is provided) is fast. If performance becomes an issue, a future proposal can add a frontmatter cache via `Goodwizard.Cache`.

### 5. Date filtering uses ISO 8601 string comparison

Filter options `after` and `before` accept ISO 8601 datetime strings and compare them lexicographically against the episode's `timestamp` field. This works because ISO 8601 strings sort chronologically when formatted consistently.

**Rationale:** Avoids importing a datetime library for comparison. The timestamp format is always ISO 8601 with UTC timezone, so string comparison is correct.

### 6. List returns frontmatter only; read returns frontmatter + body

`list/2` returns a list of frontmatter maps (no body content) for efficiency. `read/2` returns the full `{frontmatter, body}` tuple. `search/3` returns frontmatter maps enriched with a `match_context` field when a text query is provided.

**Rationale:** List and search operations scan many files — returning body content for all of them would be wasteful. The caller can follow up with `read/2` for full content on specific episodes.

## Risks / Trade-offs

**File-scan search does not scale** — Scanning hundreds of files per search is fine; thousands would be slow. Mitigation: proposal 9 adds archival at 200 files, keeping the active set manageable.

**No concurrent-write protection** — Two simultaneous `create/3` calls could theoretically generate the same UUID7 (extremely unlikely with UUID7's timestamp+random design). Mitigation: UUID7 collision probability is negligible. If it somehow occurs, the second write would overwrite the first — an acceptable risk at this scale.

**Frontmatter-only list loses context** — The caller cannot see episode body content without a separate `read/2` call. Mitigation: `summary` in frontmatter provides a one-line description. For search results, `match_context` provides the matching snippet.

**No tag normalization** — Tags are stored as-is (case-sensitive, no dedup). `["Elixir", "elixir"]` would be treated as different tags. Mitigation: tag normalization can be added to `create/3` (lowercase, dedup) without changing the file format. Deferred to keep the initial implementation simple.
