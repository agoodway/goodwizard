## ADDED Requirements

### Requirement: Episodic archival consolidates old episodes into monthly summaries

The `ArchiveOldEpisodes` action SHALL consolidate episodes older than the retention window into monthly summary episodes when the episodic store exceeds a file count threshold.

#### Scenario: Archival triggers when file count exceeds threshold

- **WHEN** `ArchiveOldEpisodes` is called
- **AND** the `memory/episodic/` directory contains more than `file_threshold` (default 200) `.md` files
- **THEN** the action SHALL proceed with archival

#### Scenario: Archival skips when file count is within threshold

- **WHEN** `ArchiveOldEpisodes` is called
- **AND** the `memory/episodic/` directory contains `file_threshold` or fewer `.md` files
- **THEN** the action SHALL return without modifying any files
- **AND** the result SHALL indicate that no archival was needed

#### Scenario: Recent episodes are retained

- **WHEN** archival proceeds
- **THEN** all episodes with a timestamp within the last `recent_days` (default 30) days SHALL be retained as individual files
- **AND** all episodes with `outcome: "success"` and a timestamp within the last `success_retention_days` (default 90) days SHALL be retained as individual files

#### Scenario: Old episodes are grouped into monthly summaries

- **WHEN** episodes outside the retention windows are identified
- **THEN** they SHALL be grouped by calendar month (YYYY-MM)
- **AND** one summary episode SHALL be created per month group

#### Scenario: Monthly summary contains aggregated information

- **WHEN** a monthly summary episode is created
- **THEN** its frontmatter SHALL have `type: "monthly_summary"`
- **AND** its tags SHALL include the month identifier (e.g., `"2025-11"`)
- **AND** its body SHALL include counts of episodes by type and outcome
- **AND** its body SHALL include key lessons extracted from the archived episodes
- **AND** its body SHALL include a list of notable event summaries

#### Scenario: Archived episodes are deleted after summarization

- **WHEN** a monthly summary is successfully written
- **THEN** the individual episode files that were summarized SHALL be deleted
- **AND** the summary episode SHALL remain in `memory/episodic/`

#### Scenario: Archival is idempotent

- **WHEN** `ArchiveOldEpisodes` is called twice in succession without new episodes being added
- **THEN** the second call SHALL NOT create duplicate monthly summaries
- **AND** the second call SHALL NOT delete any additional files

---

### Requirement: Procedural confidence decays for unused procedures

The `decay_unused/2` function in `Memory.Procedural` SHALL demote the confidence level of procedures that have not been used within a configurable time window, and delete procedures that remain at low confidence beyond a longer archival window.

#### Scenario: Recently used procedures are not demoted

- **WHEN** `decay_unused/2` is called
- **AND** a procedure has `last_used` within the last `decay_days` (default 60) days
- **THEN** its confidence level SHALL NOT be changed

#### Scenario: High-confidence procedure demoted to medium

- **WHEN** `decay_unused/2` is called
- **AND** a procedure has `confidence: "high"` and `last_used` more than `decay_days` ago (or nil)
- **THEN** its confidence SHALL be updated to `"medium"`
- **AND** its `updated_at` timestamp SHALL be refreshed

#### Scenario: Medium-confidence procedure demoted to low

- **WHEN** `decay_unused/2` is called
- **AND** a procedure has `confidence: "medium"` and `last_used` more than `decay_days` ago (or nil)
- **THEN** its confidence SHALL be updated to `"low"`
- **AND** its `updated_at` timestamp SHALL be refreshed

#### Scenario: Low-confidence procedure deleted after archival window

- **WHEN** `decay_unused/2` is called
- **AND** a procedure has `confidence: "low"` and `last_used` more than `archive_days` (default 120) days ago (or nil with `created_at` more than `archive_days` ago)
- **THEN** the procedure file SHALL be deleted from `memory/procedural/`

#### Scenario: Decay is idempotent within the same time window

- **WHEN** `decay_unused/2` is called twice in the same day
- **THEN** procedures already demoted by the first call SHALL NOT be demoted again by the second call (their `updated_at` is now recent)

---

### Requirement: DecayUnusedProcedures action wraps the decay function

The `DecayUnusedProcedures` action SHALL expose procedural confidence decay as a callable agent action.

#### Scenario: Decay action returns counts

- **WHEN** `DecayUnusedProcedures` is called
- **THEN** the result SHALL include `demoted` (integer count of procedures with lowered confidence), `deleted` (integer count of procedures removed), and `unchanged` (integer count of unaffected procedures)

---

### Requirement: Cross-type consolidation infers procedures from episodic patterns

The `CrossConsolidate` action SHALL analyze recent successful episodes to detect recurring patterns and create new procedural memories.

#### Scenario: Cross-consolidation loads recent successful episodes

- **WHEN** `CrossConsolidate` is called
- **THEN** it SHALL load up to `episode_limit` (default 20) recent episodes with `outcome: "success"`

#### Scenario: Cross-consolidation skips with insufficient episodes

- **WHEN** `CrossConsolidate` is called
- **AND** fewer than `min_episodes` (default 5) successful episodes exist
- **THEN** the action SHALL return without creating any procedures
- **AND** the result SHALL indicate insufficient data

#### Scenario: Existing procedures provided for deduplication

- **WHEN** the LLM prompt is built for cross-consolidation
- **THEN** it SHALL include summaries of all existing procedures
- **AND** the prompt SHALL instruct the LLM to only suggest procedures that do not duplicate existing ones

#### Scenario: Inferred procedures created with low confidence

- **WHEN** the LLM suggests new procedures from detected patterns
- **THEN** each procedure SHALL be created with `source: "inferred"`
- **AND** each procedure SHALL be created with `confidence: "low"`

#### Scenario: Inferred procedures have valid structure

- **WHEN** an inferred procedure is created
- **THEN** its frontmatter SHALL include valid `type`, `summary`, and `tags` fields
- **AND** its body SHALL include "When to apply", "Steps", and "Notes" sections

#### Scenario: No patterns detected

- **WHEN** the LLM analyzes the episodes and finds no recurring patterns
- **THEN** the action SHALL return with `procedures_created: 0`
- **AND** no files SHALL be written to `memory/procedural/`

#### Scenario: Cross-consolidation result includes created procedure details

- **WHEN** `CrossConsolidate` completes successfully with new procedures
- **THEN** the result SHALL include `procedures_created` (integer count) and a list of created procedure summaries

---

### Requirement: Lifecycle actions are registered as agent tools

All three lifecycle actions SHALL be registered in the agent's tool list so the agent can invoke them when appropriate.

#### Scenario: Agent can invoke episodic archival

- **WHEN** the agent needs to manage episodic memory size
- **THEN** the `ArchiveOldEpisodes` action SHALL be available in the tool list

#### Scenario: Agent can invoke confidence decay

- **WHEN** the agent needs to prune stale procedures
- **THEN** the `DecayUnusedProcedures` action SHALL be available in the tool list

#### Scenario: Agent can invoke cross-consolidation

- **WHEN** the agent needs to synthesize patterns from past experiences
- **THEN** the `CrossConsolidate` action SHALL be available in the tool list
