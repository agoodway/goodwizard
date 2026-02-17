## Context

After proposals 1-8, Goodwizard has a complete three-memory system: structured episodic and procedural stores, enhanced consolidation that populates them, and context loading that surfaces them at conversation start. What is missing is lifecycle management -- the mechanisms that keep the stores healthy over time.

The episodic store (`memory/episodic/`) grows by 1-5 files per consolidation. Over months, this can reach hundreds of files. The procedural store (`memory/procedural/`) grows more slowly but accumulates stale entries as the user's workflows and preferences evolve.

Without lifecycle management:
- `Memory.Episodic.search/3` and `list/2` slow down as file count increases
- `LoadMemoryContext` reads more files than necessary
- Procedures learned from one-off situations persist indefinitely, potentially confusing the agent
- Recurring successful patterns across episodes are never formally captured as procedures

## Goals / Non-Goals

**Goals:**

- Episodic memory stays bounded: old episodes are consolidated into monthly summaries when the store exceeds a configurable file count threshold
- Procedural confidence decays over time for unused procedures, eventually leading to archival
- Cross-type consolidation detects recurring patterns in recent successful episodes and creates new inferred procedures
- All lifecycle operations are idempotent and safe to run multiple times
- All lifecycle operations can be triggered manually (as agent actions) or automatically (during consolidation)

**Non-Goals:**

- No automatic scheduling of lifecycle operations (run on-demand or during consolidation, not on a timer)
- No semantic similarity matching for episode deduplication -- monthly summaries aggregate by time period, not by topic
- No user confirmation before archival or decay -- these are autonomous housekeeping operations
- No undo/restore for archived episodes or decayed procedures -- once archived, the summary replaces the originals
- No cross-store merging (e.g., merging episodic lessons into brain entities) -- that is beyond the current architecture

## Decisions

### 1. Episodic archival uses monthly summaries with aggregated statistics

When archiving old episodes, group them by calendar month and create one summary episode per month. The summary includes aggregated statistics (episode count by type and outcome), a list of key lessons learned, and notable events.

**Why over alternatives:**
- *Delete old episodes without summarization* -- Loses information permanently. The agent would have no awareness of distant past experiences.
- *Compress/zip old episodes* -- Adds complexity (need to decompress for search), still consumes disk space, and makes search harder.
- *Weekly summaries* -- More granular than needed. Monthly strikes the right balance between retention and compaction.

### 2. Archival threshold is file count (200), not time alone

Archival triggers when the episodic directory exceeds 200 files. Time-based retention rules (keep last 30 days, keep successful last 90 days) determine which individual episodes survive.

**Why over alternatives:**
- *Time-only trigger* (always archive after 90 days) -- Forces archival even when the store is small and manageable. Unnecessary if the user has only 50 episodes.
- *Size-based trigger* (total bytes) -- More complex to compute, and file count is a better proxy for search performance than byte size.

### 3. Procedural confidence decay uses discrete levels, not continuous scoring

Decay operates on the existing confidence levels (high, medium, low) rather than introducing a numeric score. After 60 days without use: high demotes to medium, medium demotes to low. After 120 days at low confidence without use: the procedure is deleted.

**Why over alternatives:**
- *Continuous confidence score* (e.g., 0.0-1.0 with daily decay) -- Adds complexity to the frontmatter schema and requires defining decay curves. The discrete level system is simpler and already in use.
- *Never delete, only hide* -- Accumulates dead procedures indefinitely. Deletion of truly unused low-confidence procedures is acceptable since they were likely one-off patterns.

### 4. Cross-type consolidation uses a single LLM call with episode summaries

Load the last 20 successful episodes (frontmatter + body) and all existing procedure summaries (frontmatter only). Send to the LLM with a prompt asking it to identify recurring patterns that should become new procedures. The LLM returns a JSON array of procedure definitions.

**Why over alternatives:**
- *Embedding-based similarity clustering* -- Requires an embedding model and vector similarity computation. Over-engineering for the current file-backed architecture.
- *Rule-based pattern detection* (e.g., same tags appearing in 3+ episodes) -- Too rigid. The LLM can detect semantic patterns that transcend tags.
- *Run during every consolidation* -- Too frequent and expensive. Better as a periodic operation triggered explicitly or after a threshold of new episodes.

### 5. Cross-consolidation creates procedures with `source: "inferred"` and `confidence: "low"`

Inferred procedures start at low confidence because they are pattern-detected, not directly taught or learned. They must prove themselves through usage (via `use_procedure` action) to gain confidence.

**Why:** Inferred procedures are speculative. The LLM may detect false patterns. Starting at low confidence ensures they do not dominate recall results until validated by use.

### 6. Deleted/archived items are not recoverable

Monthly summaries replace individual archived episodes. Decayed procedures are deleted permanently. No recycle bin or soft-delete mechanism.

**Why over alternatives:**
- *Soft delete with hidden flag* -- Adds complexity to all list/search queries. The monthly summary preserves the key information from archived episodes.
- *Move to archive directory* -- Creates a parallel store that needs its own management. The summary is sufficient.

## Risks / Trade-offs

- **Information loss during episodic archival** -- Monthly summaries cannot capture the full detail of individual episodes. Mitigated by preserving episodes from the last 90 days (successful) and 30 days (all), and by including key lessons in the summary.

- **Premature procedure deletion** -- A procedure unused for 120 days may still be valuable for rare situations. Mitigated by the 120-day threshold being long enough to cover seasonal patterns, and by the LLM's ability to re-learn the procedure if the situation recurs.

- **Cross-consolidation false positives** -- The LLM may detect patterns that are coincidental rather than meaningful. Mitigated by starting inferred procedures at low confidence, so they only persist if validated through use.

- **LLM cost for cross-consolidation** -- Each invocation requires a Haiku call with 20 episode bodies in the prompt. Mitigated by running infrequently (not on every consolidation) and using the cheapest capable model.

- **Archival during active use** -- If archival runs while the agent is in a conversation that references old episodes, those episodes may be deleted. Mitigated by only archiving episodes older than 30 days (well outside any active conversation window).
