## Context

The `Consolidate` action (`lib/goodwizard/actions/memory/consolidate.ex`) is Goodwizard's mechanism for compressing old conversation messages into long-term memory. Currently it:

1. Takes messages beyond the `memory_window` threshold
2. Formats them into a conversation transcript
3. Calls Claude Haiku with a prompt requesting a `history_entry` (one-line summary) and `memory_update` (updated MEMORY.md content)
4. Appends the history entry to HISTORY.md as a timestamped line
5. Overwrites MEMORY.md with the updated content
6. Returns the trimmed recent messages

With proposals 1-6 delivering `Memory.Entry`, `Memory.Episodic`, `Memory.Procedural`, path helpers, directory bootstrapping, and full action suites for both memory types, consolidation can now write structured data into all three memory stores. The LLM prompt needs to ask for richer, typed output, and the action needs to route that output to the correct stores.

## Goals / Non-Goals

**Goals:**

- The consolidation LLM prompt extracts episodes, semantic updates, and procedural insights in a single call
- Episodes are written as structured entries in `memory/episodic/` via `Memory.Episodic.create/3`
- Procedural insights become new procedures or updates to existing ones via `Memory.Procedural`
- MEMORY.md continues to receive semantic profile updates
- HISTORY.md becomes a consolidation audit log (what was extracted, when) rather than the primary episodic store
- Existing procedure summaries are provided to the LLM for deduplication
- The action remains a single LLM call -- no multi-step chains

**Non-Goals:**

- No change to the consolidation trigger logic (still message-count-based, handled by the session plugin)
- No change to the `memory_window` parameter semantics
- No migration of existing HISTORY.md entries into the episodic store -- old history stays as-is
- No additional LLM calls for quality validation of extracted memories
- No structured output / tool-use mode -- continue using JSON-in-text response parsing

## Decisions

### 1. Single LLM call with a three-section JSON response

The consolidation prompt asks the LLM to return a JSON object with three top-level keys: `episodes` (array), `memory_profile_update` (string), and `procedural_insights` (array). This keeps the consolidation to one LLM call, same as today.

**Why over alternatives:**
- *Three separate LLM calls* (one per memory type) -- 3x latency and cost for marginal quality improvement. The LLM can extract all three types from the same transcript in a single pass.
- *Structured output / tool use* -- Would require switching to a tool-calling model invocation, adding complexity. JSON-in-text works reliably with Haiku for structured extraction.

### 2. Provide existing procedure summaries in the prompt for deduplication

Before calling the LLM, load all procedure frontmatter (summary + tags + type) and include them in the prompt. This lets the LLM reference existing procedures via `updates_existing: <id>` when an insight refines rather than duplicates a known procedure.

**Why over alternatives:**
- *Post-hoc deduplication* (create all, then deduplicate) -- Wastes writes and requires fuzzy matching logic. Better to let the LLM avoid duplicates.
- *No dedup at all* -- Leads to procedure proliferation over time. The LLM is good at recognizing overlap when given context.

### 3. HISTORY.md becomes an audit log, not an episodic store

Each consolidation appends a structured summary line to HISTORY.md:
```
## 2026-02-17T10:30:00Z -- Consolidation
Extracted 2 episodes, updated memory profile, learned 1 new procedure.
Episodes: "Debugged Jido executor issue" (success), "Failed deploy attempt" (failure)
Procedure: "How to debug Jido action failures"
```

**Why over alternatives:**
- *Remove HISTORY.md entirely* -- Loses the chronological audit trail. Useful for debugging consolidation behavior.
- *Keep HISTORY.md as dual store* -- Redundant with episodic memory. Confusing to have the same data in two places.

### 4. Graceful degradation when episodic/procedural writes fail

If writing an episode or procedure fails, log a warning and continue processing the remaining items. The consolidation result includes counts of successful and failed writes. The semantic update (MEMORY.md) and message trimming still proceed.

**Why:** A single bad episode should not block the entire consolidation. The messages are already being trimmed from the session, so partial persistence is better than none.

### 5. Episodes from consolidation use `source` context in body

Each episode body includes a note that it was extracted during consolidation (not recorded in real-time). This helps distinguish consolidated episodes from directly-recorded ones when reviewing memory.

**Why:** Provenance matters for confidence. A directly-recorded episode (via `record_episode` action) has higher fidelity than one extracted after the fact by an LLM.

## Risks / Trade-offs

- **Larger LLM prompt increases cost and latency** -- Including existing procedure summaries and the three-section output format makes the prompt longer. Mitigated by only including procedure summaries (frontmatter), not full bodies. Haiku is fast and cheap enough that this is acceptable.

- **LLM extraction quality varies** -- The LLM may miss episodes or generate low-quality procedural insights. Mitigated by keeping the prompt focused with clear examples and by using medium confidence for all LLM-extracted procedures (they strengthen through use).

- **JSON parsing failures on malformed responses** -- The LLM may return invalid JSON or miss required fields. Mitigated by the existing `parse_json_response` fallback logic and by making episode/procedure arrays optional in the response (empty array = nothing to extract).

- **Procedure deduplication is best-effort** -- The LLM may still create near-duplicate procedures if the prompt context is too long. Acceptable since procedural memory has confidence decay (proposal 9) that naturally prunes unused duplicates over time.
