## ADDED Requirements

### Requirement: LearnProcedure creates a structured procedural memory entry

The `LearnProcedure` action SHALL create a new procedure file in `memory/procedural/` with auto-generated ID and timestamps, structured frontmatter including confidence and source, and a markdown body assembled from trigger conditions, steps, and notes.

#### Scenario: Learn a new workflow procedure

- **WHEN** `LearnProcedure` is called with `type: "workflow"`, `summary: "Deploy to staging"`, `source: "learned"`, `when_to_apply: "When deploying a new version to staging"`, `steps: "1. Run tests\n2. Build release\n3. Push to staging"`, `notes: "Skip on hotfixes"`
- **THEN** a new markdown file SHALL be created in `memory/procedural/`
- **AND** the frontmatter SHALL contain an auto-generated `id` (UUID7)
- **AND** the frontmatter SHALL contain auto-generated `created_at` and `updated_at` (ISO 8601)
- **AND** the frontmatter SHALL contain `type: "workflow"` and `source: "learned"`
- **AND** the frontmatter SHALL contain `usage_count: 0` and `last_used: null`
- **AND** the body SHALL contain `## When to apply`, `## Steps`, and `## Notes` sections
- **AND** the return value SHALL include `%{procedure: ..., message: "Procedure learned: Deploy to staging"}`

#### Scenario: Default confidence is medium

- **WHEN** `LearnProcedure` is called without a `confidence` parameter
- **THEN** the stored procedure SHALL have `confidence: "medium"`

#### Scenario: Summary is truncated to 200 characters

- **WHEN** `LearnProcedure` is called with a `summary` longer than 200 characters
- **THEN** the stored summary SHALL be truncated to 200 characters

#### Scenario: Invalid procedure type is rejected

- **WHEN** `LearnProcedure` is called with `type: "invalid_type"`
- **THEN** the action SHALL return an error

---

### Requirement: RecallProcedures finds relevant procedures by situation

The `RecallProcedures` action SHALL search the procedural memory store using a natural language situation description, returning procedures ranked by a weighted score incorporating tag match, text relevance, confidence level, and recency.

#### Scenario: Recall procedures for a described situation

- **WHEN** `RecallProcedures` is called with `situation: "I need to deploy to staging"`
- **AND** a procedure exists with tags `["deploy", "staging"]` and body containing "deploy" and "staging"
- **THEN** the result SHALL include that procedure in the `procedures` list
- **AND** the result SHALL include a `count` matching the number of results

#### Scenario: Recall with tag filter

- **WHEN** `RecallProcedures` is called with `situation: "deployment"` and `tags: ["staging"]`
- **AND** three procedures exist but only one has the "staging" tag
- **THEN** the result SHALL rank the tagged procedure higher

#### Scenario: Recall respects limit

- **WHEN** `RecallProcedures` is called with `limit: 2`
- **AND** 10 procedures match the situation
- **THEN** the result SHALL contain at most 2 procedures

#### Scenario: Recall from empty store

- **WHEN** `RecallProcedures` is called
- **AND** no procedures exist in the store
- **THEN** the result SHALL be `%{procedures: [], count: 0}`

#### Scenario: Higher confidence procedures rank higher

- **WHEN** `RecallProcedures` is called with a situation matching two procedures equally by tags and text
- **AND** one procedure has `confidence: "high"` and the other has `confidence: "low"`
- **THEN** the high-confidence procedure SHALL appear first in the results

---

### Requirement: UpdateProcedure modifies an existing procedure

The `UpdateProcedure` action SHALL update specified fields of an existing procedure. Only provided (non-nil) parameters are changed; all other fields are preserved. The `updated_at` timestamp SHALL be refreshed on any update.

#### Scenario: Update only the summary

- **WHEN** `UpdateProcedure` is called with `id: "<valid-id>"` and `summary: "Updated deploy process"`
- **THEN** the procedure's `summary` SHALL be changed to "Updated deploy process"
- **AND** the procedure's `updated_at` SHALL be refreshed
- **AND** all other frontmatter fields and the body SHALL remain unchanged

#### Scenario: Update body sections

- **WHEN** `UpdateProcedure` is called with `id: "<valid-id>"`, `steps: "1. New step one\n2. New step two"`, `when_to_apply: "When releasing"`, `notes: "Updated notes"`
- **THEN** the procedure's body SHALL be rebuilt with the new sections

#### Scenario: Update confidence explicitly

- **WHEN** `UpdateProcedure` is called with `id: "<valid-id>"` and `confidence: "high"`
- **THEN** the procedure's `confidence` SHALL be changed to "high"

#### Scenario: Update nonexistent procedure returns error

- **WHEN** `UpdateProcedure` is called with `id: "nonexistent-id"`
- **THEN** the action SHALL return an error tuple

---

### Requirement: UseProcedure records usage and adjusts confidence

The `UseProcedure` action SHALL record that a procedure was used with a given outcome (success or failure), incrementing the usage count, updating the last-used timestamp, and adjusting confidence according to defined thresholds.

#### Scenario: Record successful usage

- **WHEN** `UseProcedure` is called with `id: "<valid-id>"` and `outcome: "success"`
- **THEN** the procedure's `usage_count` SHALL be incremented by 1
- **AND** the procedure's `last_used` SHALL be set to the current timestamp
- **AND** the return value SHALL include `%{procedure: ..., message: "Procedure usage recorded (success)"}`

#### Scenario: Record failed usage

- **WHEN** `UseProcedure` is called with `id: "<valid-id>"` and `outcome: "failure"`
- **THEN** the procedure's `usage_count` SHALL be incremented by 1
- **AND** the procedure's `last_used` SHALL be set to the current timestamp

#### Scenario: Confidence promotes after repeated successes

- **WHEN** a procedure has `confidence: "low"` and `UseProcedure` is called with `outcome: "success"` enough times to reach the promotion threshold
- **THEN** the procedure's `confidence` SHALL be promoted to "medium"

#### Scenario: Confidence demotes after repeated failures

- **WHEN** a procedure has `confidence: "high"` and `UseProcedure` is called with `outcome: "failure"` enough times to reach the demotion threshold
- **THEN** the procedure's `confidence` SHALL be demoted to "medium"

#### Scenario: Use nonexistent procedure returns error

- **WHEN** `UseProcedure` is called with `id: "nonexistent-id"`
- **THEN** the action SHALL return an error tuple

---

### Requirement: ListProcedures returns procedures with optional filters

The `ListProcedures` action SHALL list procedures from the procedural store with optional type and confidence filters and a configurable limit.

#### Scenario: List all procedures

- **WHEN** `ListProcedures` is called with default parameters
- **THEN** the result SHALL include up to 20 procedures
- **AND** the result SHALL include a `count` field

#### Scenario: List with type filter

- **WHEN** `ListProcedures` is called with `type: "workflow"`
- **THEN** the result SHALL include only procedures with `type: "workflow"`

#### Scenario: List with confidence filter

- **WHEN** `ListProcedures` is called with `confidence: "high"`
- **THEN** the result SHALL include only procedures with `confidence: "high"` or higher

#### Scenario: List with custom limit

- **WHEN** `ListProcedures` is called with `limit: 5`
- **THEN** the result SHALL contain at most 5 procedures

#### Scenario: List from empty store

- **WHEN** `ListProcedures` is called
- **AND** no procedures exist in the store
- **THEN** the result SHALL be `%{procedures: [], count: 0}`

---

### Requirement: Procedural actions are registered as agent tools

All five procedural memory actions SHALL be listed in the `tools:` configuration of `Goodwizard.Agent` so the LLM can invoke them during the ReAct loop.

#### Scenario: Agent has procedural tools available

- **WHEN** the agent is initialized
- **THEN** the tool list SHALL include `LearnProcedure`, `RecallProcedures`, `UpdateProcedure`, `UseProcedure`, and `ListProcedures`
