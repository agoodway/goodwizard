## ADDED Requirements

### Requirement: Consolidation extracts episodic memories from conversation history

The `Consolidate` action SHALL extract structured episode records from old conversation messages and write them to the episodic memory store (`memory/episodic/`).

#### Scenario: Consolidation creates episode entries from conversation

- **WHEN** the `Consolidate` action runs with messages exceeding the memory window
- **AND** the LLM response includes one or more episodes in the `episodes` array
- **THEN** each episode SHALL be written to `memory/episodic/` via `Memory.Episodic.create/3`
- **AND** each episode SHALL have a valid `type`, `summary`, `outcome`, and body sections

#### Scenario: Episode body includes consolidation provenance

- **WHEN** an episode is created during consolidation
- **THEN** the episode body SHALL indicate it was extracted during consolidation rather than recorded in real-time

#### Scenario: No episodes extracted from conversation

- **WHEN** the `Consolidate` action runs and the LLM response contains an empty `episodes` array
- **THEN** no episodic files SHALL be created
- **AND** the consolidation SHALL still succeed and update MEMORY.md

---

### Requirement: Consolidation extracts procedural insights from conversation history

The `Consolidate` action SHALL extract procedural insights from old conversation messages and write them to the procedural memory store (`memory/procedural/`).

#### Scenario: Consolidation creates new procedure from insight

- **WHEN** the LLM response includes a procedural insight without `updates_existing` set
- **THEN** a new procedure SHALL be created via `Memory.Procedural.create/3`
- **AND** the procedure SHALL have `source` set to `"learned"`
- **AND** the procedure SHALL have `confidence` set to `"medium"`

#### Scenario: Consolidation updates existing procedure from insight

- **WHEN** the LLM response includes a procedural insight with `updates_existing` set to an existing procedure ID
- **THEN** the existing procedure SHALL be updated via `Memory.Procedural.update/4`
- **AND** the procedure's `updated_at` timestamp SHALL be refreshed

#### Scenario: No procedural insights extracted

- **WHEN** the LLM response contains an empty `procedural_insights` array
- **THEN** no procedural files SHALL be created or modified
- **AND** the consolidation SHALL still succeed

---

### Requirement: Consolidation provides existing procedures to LLM for deduplication

The `Consolidate` action SHALL include existing procedure summaries in the LLM prompt to prevent duplicate procedure creation.

#### Scenario: Existing procedures included in prompt

- **WHEN** the consolidation LLM prompt is built
- **THEN** it SHALL include a summary of all existing procedures (ID, type, summary, tags)
- **AND** the prompt SHALL instruct the LLM to reference existing procedure IDs via `updates_existing` when refining known procedures

#### Scenario: No existing procedures

- **WHEN** the procedural memory store is empty
- **THEN** the prompt SHALL indicate no existing procedures are present
- **AND** the consolidation SHALL proceed normally

---

### Requirement: HISTORY.md serves as a consolidation audit log

HISTORY.md SHALL record a structured summary of each consolidation event rather than storing the episodic content itself.

#### Scenario: Audit log entry written after consolidation

- **WHEN** a consolidation completes successfully
- **THEN** a timestamped entry SHALL be appended to HISTORY.md
- **AND** the entry SHALL include the count of episodes created, procedures created/updated, and whether MEMORY.md was updated
- **AND** the entry SHALL include a brief list of episode summaries

#### Scenario: Audit log entry on empty extraction

- **WHEN** a consolidation completes with no episodes and no procedural insights
- **THEN** a timestamped entry SHALL still be appended to HISTORY.md
- **AND** the entry SHALL note that only a semantic profile update was performed

---

### Requirement: Consolidation handles individual write failures gracefully

The `Consolidate` action SHALL continue processing remaining memory items when an individual write operation fails.

#### Scenario: Single episode write failure does not block others

- **WHEN** one episode fails to write to `memory/episodic/`
- **THEN** remaining episodes SHALL still be written
- **AND** procedural insights SHALL still be processed
- **AND** MEMORY.md SHALL still be updated
- **AND** a warning SHALL be logged for the failed episode

#### Scenario: Procedure write failure does not block other writes

- **WHEN** one procedural insight fails to write
- **THEN** remaining procedural insights SHALL still be processed
- **AND** the consolidation result SHALL include failure counts

#### Scenario: Consolidation result includes success and failure counts

- **WHEN** a consolidation completes
- **THEN** the result map SHALL include `episodes_created`, `procedures_created`, `procedures_updated`, and failure counts

---

### Requirement: Consolidation LLM prompt produces structured three-type output

The LLM prompt used by `Consolidate` SHALL request a JSON response with `episodes`, `memory_profile_update`, and `procedural_insights` fields.

#### Scenario: LLM returns valid three-type response

- **WHEN** the LLM returns a JSON object with all three keys
- **THEN** the response SHALL be parsed successfully
- **AND** each section SHALL be processed into its respective memory store

#### Scenario: LLM returns response with missing optional arrays

- **WHEN** the LLM returns a JSON object with `memory_profile_update` but without `episodes` or `procedural_insights` keys
- **THEN** the missing arrays SHALL default to empty arrays
- **AND** only the semantic profile update SHALL be applied

#### Scenario: LLM returns malformed JSON

- **WHEN** the LLM returns unparseable content
- **THEN** the consolidation SHALL fail gracefully with an error message
- **AND** the original messages SHALL be returned untrimmed
