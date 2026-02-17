## Context

This is the third change in a 9-proposal series implementing Goodwizard's three-memory architecture (`docs/memory-system-plan.md`). It builds on `memory-1-entry-parser`, which provides `Memory.Entry` for markdown+YAML parsing and `Memory.Paths` for procedural path helpers.

Procedural memory stores learned behavioral patterns — workflows, preferences, rules, strategies, and tool usage patterns. Unlike episodic memory (which records what happened), procedural memory captures how to do things. Procedures are mutable: they can be updated as the agent refines its understanding, and their confidence levels shift automatically based on usage outcomes.

The module is more complex than `Memory.Episodic` because it includes:
- Full CRUD (including update, which episodic does not have)
- Scored recall with a multi-factor ranking algorithm
- Usage tracking with automatic confidence adjustment

Key files:
- `lib/goodwizard/memory/entry.ex` — parser/serializer (from proposal 1)
- `lib/goodwizard/memory/paths.ex` — path helpers (from proposal 1)
- `lib/goodwizard/brain/id.ex` — UUID7 generation (existing)
- `lib/goodwizard/memory/procedural.ex` — new module (this proposal)

## Goals / Non-Goals

**Goals:**
- Create, read, update, list, and delete procedural memory entries as individual markdown files
- Auto-generate UUID7 IDs and ISO 8601 timestamps on creation; auto-update `updated_at` on modification
- Validate required frontmatter fields (type, summary, source) and allowed values at the module level
- Implement scored recall that ranks procedures by relevance to a described situation
- Track usage outcomes (success/failure) and automatically adjust confidence levels
- Maintain `usage_count`, `success_count`, `failure_count`, and `last_used` fields

**Non-Goals:**
- Agent-facing Jido actions (see proposal 6: `memory-6-procedural-actions`)
- Semantic/vector search (text substring + tag matching is sufficient)
- Confidence decay for unused procedures (see proposal 9: `memory-9-lifecycle-management`)
- LLM-assisted recall or pattern detection (see proposals 7 and 9)
- Directory bootstrapping (see proposal 4: `memory-4-bootstrap-and-preamble`)

## Decisions

### 1. Procedures are mutable

Unlike episodes, procedures have an `update/4` function. The agent's understanding of how to do something improves over time, and procedures should reflect the current best approach rather than preserving historical versions.

**Rationale:** Procedural memory in cognitive science is refined through practice. Keeping only the latest version reduces file clutter and ensures recall always returns the best-known approach. The `updated_at` timestamp and usage counts provide an audit trail.

**Alternative considered:** Append-only with versioning (new file per revision, linked by a `previous_version` field). Rejected because it complicates recall (which version to return?) and multiplies files. Historical changes are captured in episodic memory instead.

### 2. Confidence adjustment thresholds

Confidence promotion and demotion use cumulative outcome counts:
- **Promote:** low -> medium after 3 cumulative successes; medium -> high after 5 cumulative successes
- **Demote:** high -> medium after 2 cumulative failures; medium -> low after 3 cumulative failures
- Thresholds are evaluated against `success_count` and `failure_count` fields, not ratios

**Rationale:** Simple threshold-based rules are predictable and debuggable. The agent can inspect `success_count` and `failure_count` to understand why a procedure has its current confidence. Ratio-based approaches are fragile with small sample sizes (1 failure out of 2 uses = 50% failure rate, which seems worse than it is).

**Alternative considered:** Bayesian confidence scoring. Rejected as over-engineered for the file-based store. Can be revisited if the system moves to a database backend.

### 3. Recall scoring formula

```
score = tag_match_score * 0.4
      + text_relevance  * 0.3
      + confidence_score * 0.2   # high=1.0, medium=0.6, low=0.3
      + recency_score   * 0.1   # decays over time from last_used
```

- **tag_match_score:** Fraction of query tags that match procedure tags (Jaccard-like). Range [0, 1].
- **text_relevance:** Fraction of query words found in summary + body (case-insensitive). Range [0, 1].
- **confidence_score:** Fixed mapping from confidence level. Range [0.3, 1.0].
- **recency_score:** Linear decay over 90 days from `last_used`. Procedures never used get 0. Range [0, 1].

**Rationale:** Tag matching is weighted highest because tags are the most intentional metadata. Text relevance captures semantic alignment without requiring an embedding model. Confidence reflects learned reliability. Recency provides a mild preference for recently-validated procedures.

**Alternative considered:** Equal weighting across all factors. Rejected because tag matches are much higher signal than text substring matches, and the weights should reflect that.

### 4. Update merges frontmatter, optionally replaces body

`update/4` takes a map of frontmatter updates (merged into existing frontmatter) and an optional body string (replaces existing body if provided, keeps existing if nil). The `updated_at` field is auto-set.

**Rationale:** Partial frontmatter updates are the common case (e.g., changing confidence or adding a tag). Full body replacement is needed when rewriting steps. This API handles both without requiring the caller to read-modify-write the entire entry.

### 5. Frontmatter includes success_count and failure_count

In addition to `usage_count`, the frontmatter stores `success_count` and `failure_count` separately. This allows the confidence adjustment logic to use absolute counts rather than ratios and makes the procedure's track record transparent.

**Rationale:** `usage_count` alone is insufficient for confidence adjustment decisions. Storing both counts avoids needing to derive one from the other and makes the data self-documenting.

## Risks / Trade-offs

**Recall scoring is heuristic** — The weighted formula may not surface the most relevant procedure in all cases. A procedure with perfect tag match but low confidence may outscore a high-confidence procedure with partial tag match. Mitigation: the weights are tunable module attributes. LLM-assisted recall (proposal 7+) can supplement the heuristic.

**Word-level text matching is crude** — Splitting on whitespace and matching individual words can produce false positives (e.g., "deploy" matching "deploy" in an unrelated context). Mitigation: text relevance is only 30% of the score. Tag matching and confidence carry more weight.

**No concurrent-write protection** — Two simultaneous `update/4` or `record_usage/3` calls on the same procedure could cause a lost update. Mitigation: Goodwizard is single-agent; concurrent writes to the same procedure are unlikely. If needed, file locking can be added later.

**Confidence adjustment is one-directional per outcome** — A single failure demotes confidence even if the procedure has 100 prior successes. The threshold-based approach partially mitigates this (high -> medium requires 2 failures), but procedures with mixed results may oscillate. Mitigation: the thresholds are conservative, and the agent can manually set confidence via `update/4`.

**No dedup on create** — Two procedures with identical summaries and tags can coexist. Mitigation: dedup is intentionally deferred to proposal 7 (enhanced consolidation), which uses the LLM to identify duplicates across existing procedures.
