## Context

Goodwizard actions are Jido Action modules that define a `name`, `description`, and `schema` (NimbleOptions params) and implement a `run/2` callback. The agent invokes them as tools during the ReAct loop. Existing memory actions follow this pattern and are registered in the `tools:` list in `Goodwizard.Agent`.

The `Memory.Procedural` module (proposal 3) provides `create/3`, `read/2`, `update/4`, `recall/3`, `list/2`, and `record_usage/3` functions. Procedural memory differs from episodic memory in three ways: procedures are mutable (can be updated), they have confidence levels that adjust based on usage outcomes, and recall uses a weighted scoring algorithm (tag match, text relevance, confidence, recency) rather than simple search.

## Goals / Non-Goals

**Goals:**

- Five actions covering the full procedural memory surface: learn (create), recall (search), update, use (track), list
- Each action uses `use Jido.Action` with descriptive `name`, `description`, and typed `schema`
- Memory directory resolved from action context with Config fallback
- Return values are maps with descriptive keys suitable for LLM consumption
- `LearnProcedure` takes structured body sections (when_to_apply, steps, notes) as separate params
- `RecallProcedures` exposes the situation-based search with optional tag and type filters
- `UpdateProcedure` supports partial updates -- only provided fields are changed
- `UseProcedure` wraps the confidence-adjusting usage tracker
- Actions are registered as agent tools

**Non-Goals:**

- No automatic procedure learning -- the agent decides when to learn (consolidation handles automatic extraction in proposal 7)
- No procedure deletion action -- procedures with low confidence decay naturally (proposal 9)
- No procedure merging or deduplication -- handled by cross-consolidation in proposal 9
- No direct confidence manipulation -- confidence changes only through `UseProcedure` outcomes or `UpdateProcedure` explicit override

## Decisions

### 1. Five actions matching the store's public API

Map one action to each major store operation: create -> LearnProcedure, recall -> RecallProcedures, update -> UpdateProcedure, record_usage -> UseProcedure, list -> ListProcedures. The naming uses domain language ("learn", "recall", "use") rather than CRUD terms to guide the LLM toward the right mental model.

**Why over CRUD naming:**
- *CreateProcedure/SearchProcedures/etc.* -- technically accurate but misses the cognitive framing; "learn" tells the LLM this is about internalizing knowledge, not filing records
- *Fewer combined actions* -- same reasoning as episodic actions; individual tools with clear names are easier for the model to select

### 2. LearnProcedure takes structured body sections as separate params

The action schema has `when_to_apply`, `steps`, and `notes` as individual string params. The action assembles them into the conventional markdown body. This mirrors the `RecordEpisode` pattern from proposal 5.

**Why over a freeform body param:**
- Structured params guide the LLM to think through trigger conditions separately from steps
- Consistent with the episodic action pattern, reducing cognitive load for understanding the codebase

### 3. UpdateProcedure supports partial updates via optional params

All update params (`summary`, `tags`, `confidence`, `when_to_apply`, `steps`, `notes`) are optional. Only non-nil params are applied. The action reads the current procedure, merges changes, and writes back.

**Why over requiring all fields:**
- Partial updates are the common case -- the agent usually wants to refine one aspect (e.g., add a step, adjust confidence)
- Requiring all fields would force the agent to read the procedure first just to echo back unchanged values

### 4. UseProcedure is a separate action from UpdateProcedure

Recording usage (which adjusts confidence automatically based on outcome) is distinct from manual updates. This separation ensures the confidence adjustment logic in `record_usage/3` is always triggered when the agent uses a procedure, even if it does not want to change any fields.

**Why over combining with UpdateProcedure:**
- *Single action with optional outcome param* -- would make it unclear whether passing `outcome` triggers confidence adjustment or just records metadata
- *Separate action* -- clear intent: "I used this and it worked/failed" is a different operation from "I want to change step 3"

### 5. RecallProcedures takes a situation description, not a keyword query

The primary param is `situation` (required, string) describing what the agent is trying to accomplish. This maps to the store's `recall/3` which uses weighted scoring across tags, text, confidence, and recency.

**Why over a keyword query param:**
- The recall scoring algorithm works best with natural language situation descriptions
- Guides the LLM to describe its current task rather than guess at keywords
- Tags and type are available as optional filters for narrowing

### 6. Register actions in the static tools list

Same approach as proposal 5 -- add the 5 modules to the `tools:` list in `Goodwizard.Agent`.

**Why not a plugin-based registration:** Same reasoning as episodic actions. These are always-on tools, not conditional.

## Risks / Trade-offs

- **LLM may learn redundant procedures** -- Without deduplication, the agent might create multiple procedures for similar tasks. Mitigated by the `RecallProcedures` action (agent can check before learning) and future cross-consolidation (proposal 9).

- **Confidence adjustment thresholds are hardcoded in the store** -- The promotion/demotion thresholds (e.g., low->medium after 3 successes) are in `Memory.Procedural`, not configurable via actions. This is acceptable for the initial implementation; thresholds can be made configurable later if needed.

- **Partial update race condition** -- If two concurrent processes update the same procedure, the last write wins. Acceptable because Goodwizard is single-agent with one turn at a time; concurrent procedural updates do not occur in practice.

- **Tool list growth** -- Adding 5 more tools (on top of 4 episodic) increases the tool descriptions by ~500 tokens. Combined with proposal 5, the memory actions add ~900 tokens to each turn. This is within acceptable bounds for current context windows but worth monitoring.

- **UpdateProcedure body reconstruction** -- When updating only frontmatter (not body sections), the existing body is preserved. When any body section is updated, the entire body is reconstructed from the three sections. This means partial body updates (changing only steps but not when_to_apply) require passing all three sections. This trade-off keeps the action simple at the cost of requiring the agent to read the procedure first when partially updating the body.
