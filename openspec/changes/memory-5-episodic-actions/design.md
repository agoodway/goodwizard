## Context

Goodwizard actions are Jido Action modules that define a `name`, `description`, and `schema` (NimbleOptions params) and implement a `run/2` callback. The agent invokes them as tools during the ReAct loop. Existing memory actions (`ReadLongTerm`, `WriteLongTerm`, `AppendHistory`, `SearchHistory`, `Consolidate`) follow this pattern and are registered in the `tools:` list in `Goodwizard.Agent`.

The `Memory.Episodic` module (proposal 2) provides `create/3`, `read/2`, `search/3`, and `list/2` functions operating on the `memory/episodic/` directory. These actions wrap those functions with Jido Action schemas, memory directory resolution, and formatted return values suitable for LLM consumption.

## Goals / Non-Goals

**Goals:**

- Four actions covering the full episodic memory CRUD surface: record, search, read, list
- Each action uses `use Jido.Action` with descriptive `name`, `description`, and typed `schema`
- Memory directory is resolved from action context using the standard helper pattern with Config fallback
- Return values are maps with descriptive keys that the LLM can interpret (e.g., `%{episode: ..., message: "..."}`)
- Actions are registered as agent tools so the LLM can call them
- Action descriptions guide the LLM on when to use each tool

**Non-Goals:**

- No automatic episode recording -- the agent decides when to record (consolidation handles automatic extraction in proposal 7)
- No batch operations (record multiple episodes at once)
- No episode deletion action -- episodes are immutable records; lifecycle management comes in proposal 9
- No caching of episode data -- the file store is fast enough for expected volumes (<200 files)

## Decisions

### 1. Four actions matching the store's public API

Map one action to each major store operation: create -> RecordEpisode, search -> SearchEpisodes, read -> ReadEpisode, list -> ListEpisodes. This is a 1:1 mapping that keeps actions thin and predictable.

**Why over fewer combined actions:**
- *Single "ManageEpisodes" action with an `operation` param* -- forces the LLM to understand a dispatch pattern; individual tools with clear names and separate schemas are easier for the model to select correctly
- *Omitting ReadEpisode* -- the LLM sometimes needs to drill into a specific episode after a search returns summaries; a dedicated read action is cleaner than overloading search

### 2. RecordEpisode takes structured body sections as separate params

The action schema has `observation`, `approach`, `result`, and `lessons` as individual string params rather than a single `body` param. The action assembles them into the conventional markdown body format.

**Why over a freeform body param:**
- Structured params guide the LLM to provide all relevant sections
- The schema's `doc` strings act as prompts ("What was the situation?", "What strategy was taken?")
- The resulting markdown is consistent across all episodes

### 3. SearchEpisodes combines text query and filters in one action

A single search action accepts an optional text query plus optional filter params (tags, type, outcome, limit). This matches how the LLM naturally phrases search requests -- sometimes by keyword, sometimes by filter, often both.

**Why over separate search-by-text and filter actions:**
- *Two actions* -- forces the LLM to choose between search modes when it often wants both
- *One action with flexible params* -- the underlying `Episodic.search/3` already supports this combined mode

### 4. Memory directory resolution follows existing action conventions

Each action resolves the memory directory using a helper that checks `context` state first, then falls back to `Goodwizard.Config.workspace()` + `/memory`. This matches the pattern documented in CLAUDE.md for all workspace-dependent actions.

**Why not pass memory_dir as an action param:** The memory directory is infrastructure, not user intent. Exposing it as a param would confuse the LLM and create a path traversal surface.

### 5. Register actions in the static tools list in `Goodwizard.Agent`

Add the 4 new action modules to the `tools:` list alongside existing memory actions. This is the simplest registration path and matches how all other actions are registered.

**Why over dynamic registration:** The episodic actions are always available, not conditional on workspace state. Static registration is simpler and avoids the complexity of the `ensure_brain_tools` dynamic pattern.

## Risks / Trade-offs

- **LLM may over-record episodes** -- Without guidance on what constitutes a "notable" experience, the agent might record trivial interactions. Mitigated by the action description ("Record a notable experience") and future consolidation logic (proposal 7) that handles automatic extraction with better judgment.

- **Search performance degrades with many episodes** -- The file-scan search approach works for <200 files but slows beyond that. Proposal 9 (lifecycle management) addresses this with archival. For now, the `limit` param caps result processing.

- **No validation of entity references in `entities_involved`** -- The param accepts freeform strings, not validated brain entity IDs. This is intentional -- cross-referencing is informational, not enforced, keeping the action simple and avoiding a hard dependency on brain state.

- **Tool list growth** -- Adding 4 more tools increases the tool descriptions sent to the LLM. At ~100 tokens per tool, this adds ~400 tokens to each turn. Acceptable given the current tool count (~35) and typical context window sizes.
