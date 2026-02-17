## Why

Goodwizard's current consolidation action (`Consolidate`) extracts a flat `history_entry` string and a `memory_update` string from old messages. This approach predates the three-memory architecture introduced in proposals 1-6. Now that episodic and procedural memory stores exist, consolidation should populate them. Valuable experience records and learned procedures are being lost because the consolidator only knows how to write a one-line history summary and update the semantic memory profile.

Additionally, HISTORY.md currently serves as the primary episodic record, but its unstructured format (timestamped one-liners) makes it impossible to search, filter, or recall past experiences effectively. The structured episodic store (`memory/episodic/`) is a far better home for experience records. HISTORY.md should become a lightweight consolidation audit log instead.

This is proposal 7 of 9 in the memory system series. See `docs/memory-system-plan.md` (Phase 3, sections 3.1 and 3.2) for the full architecture context.

## What Changes

- **Refactor the LLM consolidation prompt** to extract three types of output: episodic memories, semantic memory profile updates, and procedural insights -- instead of the current flat `history_entry` + `memory_update` pair
- **Update `Consolidate.run/2`** to process the structured LLM response: create episodic entries via `Memory.Episodic.create/3`, create or update procedural entries via `Memory.Procedural.create/3` or `Memory.Procedural.update/4`, and write the updated MEMORY.md
- **Load existing procedure summaries** before calling the LLM to enable deduplication of procedural insights against known procedures
- **Change HISTORY.md role** from primary episodic store to a consolidation audit log that records what was extracted (episode count, procedure count, summary) rather than the experience itself
- **Update the JSON response schema** expected from the LLM to include `episodes`, `memory_profile_update`, and `procedural_insights` fields

## Capabilities

### New Capabilities

- `enhanced-consolidation`: Three-type memory extraction during consolidation, producing structured episodic entries, semantic profile updates, and procedural insights from conversation history

### Modified Capabilities

_(none -- this refactors the existing consolidation action, no new specs from prior proposals are affected)_

## Impact

- **`lib/goodwizard/actions/memory/consolidate.ex`** -- Major refactor: new LLM prompt, new response parsing, new write logic for episodic/procedural stores
- **`priv/workspace/memory/HISTORY.md`** -- Role change from episodic store to consolidation audit log (format change, no code impact)
- **Dependencies**: Requires `Memory.Episodic` and `Memory.Procedural` modules from proposals 1-6
- **No new files** -- this is a refactor of an existing action
- **Tests**: Existing consolidation tests need significant updates for the new response format and multi-store writes

## Prerequisites

- `memory-5-episodic-actions` -- Episodic memory actions and `Memory.Episodic` module must exist
- `memory-6-procedural-actions` -- Procedural memory actions and `Memory.Procedural` module must exist
