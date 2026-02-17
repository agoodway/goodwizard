## Why

Episodic and procedural memory stores grow without bound. Every consolidation can produce new episodes and procedures, and there is no mechanism to prune, archive, or age out stale entries. Over weeks and months of use:

- The episodic store accumulates hundreds of files, slowing search and context loading
- Procedures that were learned from one-off situations persist at the same confidence level forever, even when never used again
- Patterns that recur across multiple episodes are never synthesized into procedures unless the consolidation prompt happens to catch them in a single batch

The three-memory architecture needs lifecycle management to remain useful over time. Without it, signal degrades as noise accumulates.

This is proposal 9 of 9 in the memory system series. See `docs/memory-system-plan.md` (Phase 5, sections 5.1, 5.2, and 5.3) for the full architecture context.

## What Changes

Three lifecycle features:

1. **Episodic archival** -- When the episodic store exceeds 200 files, consolidate episodes older than 90 days into monthly summary episodes. Keep all episodes from the last 30 days and successful episodes from the last 90 days as individual entries. Delete the individual episodes after consolidation into summaries.

2. **Procedural confidence decay** -- Demote the confidence level of procedures not used in 60 days (high to medium, medium to low). Archive or delete procedures at low confidence that have not been used in 120 days.

3. **Cross-type consolidation** -- Analyze recent successful episodes to identify recurring patterns that should become new procedures. Uses an LLM call to detect patterns across episodes and create procedures with `source: "inferred"`.

## Capabilities

### New Capabilities

- `lifecycle-management`: Episodic archival into monthly summaries, procedural confidence decay for unused procedures, and cross-type consolidation that infers new procedures from episodic patterns

### Modified Capabilities

_(none -- these are new lifecycle operations, not modifications of existing specs)_

## Impact

- **`lib/goodwizard/actions/memory/episodic/archive_old.ex`** (new) -- Episodic archival action
- **`lib/goodwizard/memory/procedural.ex`** (modified) -- Add `decay_unused/2` function for confidence decay
- **`lib/goodwizard/actions/memory/procedural/decay_unused.ex`** (new) -- Action wrapper for confidence decay
- **`lib/goodwizard/actions/memory/cross_consolidate.ex`** (new) -- Cross-type consolidation action
- **Dependencies**: Requires all previous memory proposals (1-8) for the stores, actions, and context loading to be in place
- **LLM usage**: Cross-type consolidation makes one LLM call per invocation (same as regular consolidation)
- **File system**: Archival deletes individual episode files after creating monthly summaries

## Prerequisites

- `memory-7-enhanced-consolidation` -- Enhanced consolidation must exist so lifecycle operations complement rather than conflict with the consolidation flow
- `memory-8-context-loading` -- Context loading must exist so archived summaries and decayed procedures are properly surfaced (or excluded) at conversation start
