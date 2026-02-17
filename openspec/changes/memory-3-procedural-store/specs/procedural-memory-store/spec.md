## ADDED Requirements

### Requirement: Create procedural memory entries

The system SHALL create procedural memory entries as individual markdown files in `memory/procedural/`. Each entry SHALL have an auto-generated UUID7 id, `created_at`, and `updated_at` timestamps. The system SHALL validate that required frontmatter fields (`type`, `summary`, `source`) are present and that `type`, `confidence`, and `source` are within their allowed value sets. Usage tracking fields (`usage_count`, `success_count`, `failure_count`) SHALL be initialized to 0 and `last_used` SHALL be initialized to null.

#### Scenario: Create a valid procedure

- **WHEN** `create/3` is called with a valid frontmatter map containing type, summary, and source, and a body string
- **THEN** the system writes a markdown file to `memory/procedural/<uuid7>.md`
- **AND** the frontmatter includes auto-generated `id`, `created_at`, and `updated_at` fields
- **AND** `usage_count`, `success_count`, and `failure_count` are set to 0
- **AND** `last_used` is set to null
- **AND** returns `{:ok, frontmatter_map}`

#### Scenario: Default confidence level

- **WHEN** `create/3` is called without a `confidence` field in the frontmatter
- **THEN** the stored frontmatter has `confidence` set to `"medium"`

#### Scenario: Reject missing required fields

- **WHEN** `create/3` is called with a frontmatter map missing the `source` field
- **THEN** the system returns `{:error, {:missing_required, "source"}}`

#### Scenario: Reject invalid procedure type

- **WHEN** `create/3` is called with `type` set to `"unknown"`
- **THEN** the system returns `{:error, {:invalid_type, "unknown"}}`

#### Scenario: Reject invalid confidence level

- **WHEN** `create/3` is called with `confidence` set to `"very_high"`
- **THEN** the system returns `{:error, {:invalid_confidence, "very_high"}}`

#### Scenario: Reject invalid source type

- **WHEN** `create/3` is called with `source` set to `"guessed"`
- **THEN** the system returns `{:error, {:invalid_source, "guessed"}}`

### Requirement: Read procedural memory entries

The system SHALL read a procedural memory entry by its ID, returning the full frontmatter map and body string.

#### Scenario: Read an existing procedure

- **WHEN** `read/2` is called with a valid procedure ID
- **THEN** the system returns `{:ok, {frontmatter_map, body_string}}`

#### Scenario: Read a non-existent procedure

- **WHEN** `read/2` is called with an ID that does not correspond to any file
- **THEN** the system returns `{:error, :not_found}`

### Requirement: Update procedural memory entries

The system SHALL update a procedure's frontmatter and optionally its body. Frontmatter updates SHALL be merged into the existing frontmatter. Auto-managed fields (`id`, `created_at`, `usage_count`, `success_count`, `failure_count`, `last_used`) SHALL NOT be overwritten by the caller. The `updated_at` field SHALL be set to the current timestamp on every update.

#### Scenario: Update frontmatter fields

- **WHEN** `update/4` is called with `%{"confidence" => "high"}` as frontmatter updates and nil as body
- **THEN** the procedure's confidence is updated to `"high"`
- **AND** `updated_at` is set to the current timestamp
- **AND** all other frontmatter fields are preserved unchanged
- **AND** the body is preserved unchanged

#### Scenario: Update body content

- **WHEN** `update/4` is called with an empty frontmatter updates map and a new body string
- **THEN** the procedure's body is replaced with the new string
- **AND** `updated_at` is set to the current timestamp
- **AND** all frontmatter fields are preserved unchanged

#### Scenario: Auto-managed fields cannot be overwritten

- **WHEN** `update/4` is called with `%{"usage_count" => 999}` in frontmatter updates
- **THEN** the `usage_count` field retains its existing value and is not changed to 999

#### Scenario: Update non-existent procedure

- **WHEN** `update/4` is called with an ID that does not correspond to any file
- **THEN** the system returns `{:error, :not_found}`

### Requirement: List procedural memory entries

The system SHALL list procedural memory entries with optional filters. Results SHALL be sorted by `updated_at` descending (most recently modified first). Only frontmatter maps SHALL be returned (no body content).

#### Scenario: List all procedures

- **WHEN** `list/2` is called with no filter options
- **THEN** the system returns `{:ok, [frontmatter_map, ...]}` sorted by `updated_at` descending
- **AND** the default limit of 20 is applied

#### Scenario: Filter by procedure type

- **WHEN** `list/2` is called with `type: "workflow"`
- **THEN** only procedures with `type` equal to `"workflow"` are returned

#### Scenario: Filter by minimum confidence

- **WHEN** `list/2` is called with `confidence: "medium"`
- **THEN** only procedures with confidence `"medium"` or `"high"` are returned

#### Scenario: Filter by tags (intersection)

- **WHEN** `list/2` is called with `tags: ["deploy", "docker"]`
- **THEN** only procedures whose `tags` list contains both `"deploy"` and `"docker"` are returned

#### Scenario: Filter by minimum usage count

- **WHEN** `list/2` is called with `min_usage_count: 3`
- **THEN** only procedures with `usage_count` >= 3 are returned

#### Scenario: Empty directory

- **WHEN** `list/2` is called and the `memory/procedural/` directory is empty or does not exist
- **THEN** the system returns `{:ok, []}`

### Requirement: Delete procedural memory entries

The system SHALL delete a procedural memory entry by its ID.

#### Scenario: Delete an existing procedure

- **WHEN** `delete/2` is called with a valid procedure ID
- **THEN** the file is removed from `memory/procedural/`
- **AND** the system returns `:ok`

#### Scenario: Delete a non-existent procedure

- **WHEN** `delete/2` is called with an ID that does not correspond to any file
- **THEN** the system returns `{:error, :not_found}`

### Requirement: Recall procedures by situation relevance

The system SHALL find procedures relevant to a given situation description by computing a weighted relevance score. The score SHALL be computed as: `tag_match * 0.4 + text_relevance * 0.3 + confidence_score * 0.2 + recency_score * 0.1`. Results SHALL be sorted by score descending.

#### Scenario: Recall with matching tags

- **WHEN** `recall/3` is called with situation `"deploy the app"` and tags `["deploy"]`
- **AND** a procedure exists with tags `["deploy", "docker"]`
- **THEN** that procedure receives a non-zero tag_match score component

#### Scenario: Recall with text relevance

- **WHEN** `recall/3` is called with situation `"fix the failing test suite"`
- **AND** a procedure exists with summary `"How to debug failing tests"`
- **THEN** that procedure receives a non-zero text_relevance score component

#### Scenario: High-confidence procedures score higher

- **WHEN** two procedures have identical tag and text scores
- **AND** one has confidence `"high"` and the other has confidence `"low"`
- **THEN** the high-confidence procedure has a higher total score

#### Scenario: Recently-used procedures score higher

- **WHEN** two procedures have identical tag, text, and confidence scores
- **AND** one was last used yesterday and the other was last used 60 days ago
- **THEN** the recently-used procedure has a higher total score

#### Scenario: Recall respects limit

- **WHEN** `recall/3` is called with `limit: 3`
- **THEN** at most 3 results are returned

#### Scenario: Recall with empty store

- **WHEN** `recall/3` is called and no procedures exist
- **THEN** the system returns `{:ok, []}`

#### Scenario: Recall with minimum confidence filter

- **WHEN** `recall/3` is called with `min_confidence: "medium"`
- **THEN** only procedures with confidence `"medium"` or `"high"` are scored and returned

### Requirement: Track procedure usage and adjust confidence

The system SHALL record usage of a procedure and automatically adjust its confidence level based on cumulative outcome history. On each usage, `usage_count` SHALL be incremented, the corresponding outcome counter (`success_count` or `failure_count`) SHALL be incremented, and `last_used` SHALL be updated to the current timestamp.

#### Scenario: Record successful usage

- **WHEN** `record_usage/3` is called with outcome `:success`
- **THEN** `usage_count` is incremented by 1
- **AND** `success_count` is incremented by 1
- **AND** `last_used` is updated to the current timestamp

#### Scenario: Record failed usage

- **WHEN** `record_usage/3` is called with outcome `:failure`
- **THEN** `usage_count` is incremented by 1
- **AND** `failure_count` is incremented by 1
- **AND** `last_used` is updated to the current timestamp

#### Scenario: Confidence promotion from low to medium

- **WHEN** a procedure with confidence `"low"` reaches 3 cumulative successes via `record_usage/3`
- **THEN** its confidence is promoted to `"medium"`

#### Scenario: Confidence promotion from medium to high

- **WHEN** a procedure with confidence `"medium"` reaches 5 cumulative successes via `record_usage/3`
- **THEN** its confidence is promoted to `"high"`

#### Scenario: Confidence demotion from high to medium

- **WHEN** a procedure with confidence `"high"` reaches 2 cumulative failures via `record_usage/3`
- **THEN** its confidence is demoted to `"medium"`

#### Scenario: Confidence demotion from medium to low

- **WHEN** a procedure with confidence `"medium"` reaches 3 cumulative failures via `record_usage/3`
- **THEN** its confidence is demoted to `"low"`

#### Scenario: Record usage for non-existent procedure

- **WHEN** `record_usage/3` is called with an ID that does not correspond to any file
- **THEN** the system returns `{:error, :not_found}`
