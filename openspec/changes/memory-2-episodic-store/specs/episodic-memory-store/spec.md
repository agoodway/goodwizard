## ADDED Requirements

### Requirement: Create episodic memory entries

The system SHALL create episodic memory entries as individual markdown files in `memory/episodic/`. Each entry SHALL have an auto-generated UUID7 id and ISO 8601 timestamp. The system SHALL validate that required frontmatter fields (`type`, `summary`, `outcome`) are present and that `type` and `outcome` are within their allowed value sets.

#### Scenario: Create a valid episode

- **WHEN** `create/3` is called with a valid frontmatter map containing type, summary, and outcome, and a body string
- **THEN** the system writes a markdown file to `memory/episodic/<uuid7>.md`
- **AND** the frontmatter includes auto-generated `id` and `timestamp` fields
- **AND** returns `{:ok, frontmatter_map}` with all fields including the generated ones

#### Scenario: Reject missing required fields

- **WHEN** `create/3` is called with a frontmatter map missing the `type` field
- **THEN** the system returns `{:error, {:missing_required, "type"}}`

#### Scenario: Reject invalid episode type

- **WHEN** `create/3` is called with `type` set to `"unknown_type"`
- **THEN** the system returns `{:error, {:invalid_type, "unknown_type"}}`

#### Scenario: Reject invalid outcome type

- **WHEN** `create/3` is called with `outcome` set to `"maybe"`
- **THEN** the system returns `{:error, {:invalid_outcome, "maybe"}}`

#### Scenario: Truncate oversized summary

- **WHEN** `create/3` is called with a `summary` longer than 200 characters
- **THEN** the system truncates the summary to 200 characters before storing

#### Scenario: Default values for optional fields

- **WHEN** `create/3` is called without `tags` or `entities_involved`
- **THEN** the stored frontmatter has `tags` as an empty list and `entities_involved` as an empty list

### Requirement: Read episodic memory entries

The system SHALL read an episodic memory entry by its ID, returning the full frontmatter map and body string.

#### Scenario: Read an existing episode

- **WHEN** `read/2` is called with a valid episode ID
- **THEN** the system returns `{:ok, {frontmatter_map, body_string}}`

#### Scenario: Read a non-existent episode

- **WHEN** `read/2` is called with an ID that does not correspond to any file
- **THEN** the system returns `{:error, :not_found}`

### Requirement: List episodic memory entries

The system SHALL list episodic memory entries with optional filters. Results SHALL be sorted by timestamp descending (most recent first). Only frontmatter maps SHALL be returned (no body content).

#### Scenario: List all episodes

- **WHEN** `list/2` is called with no filter options
- **THEN** the system returns `{:ok, [frontmatter_map, ...]}` sorted by timestamp descending
- **AND** the default limit of 20 is applied

#### Scenario: Filter by episode type

- **WHEN** `list/2` is called with `type: "problem_solved"`
- **THEN** only episodes with `type` equal to `"problem_solved"` are returned

#### Scenario: Filter by outcome

- **WHEN** `list/2` is called with `outcome: "success"`
- **THEN** only episodes with `outcome` equal to `"success"` are returned

#### Scenario: Filter by tags (intersection)

- **WHEN** `list/2` is called with `tags: ["elixir", "debug"]`
- **THEN** only episodes whose `tags` list contains both `"elixir"` and `"debug"` are returned

#### Scenario: Filter by date range

- **WHEN** `list/2` is called with `after: "2026-02-01T00:00:00Z"` and `before: "2026-02-15T00:00:00Z"`
- **THEN** only episodes with `timestamp` between the two values (inclusive of after, exclusive of before) are returned

#### Scenario: Custom limit

- **WHEN** `list/2` is called with `limit: 5`
- **THEN** at most 5 episodes are returned

#### Scenario: Empty directory

- **WHEN** `list/2` is called and the `memory/episodic/` directory is empty or does not exist
- **THEN** the system returns `{:ok, []}`

### Requirement: Delete episodic memory entries

The system SHALL delete an episodic memory entry by its ID.

#### Scenario: Delete an existing episode

- **WHEN** `delete/2` is called with a valid episode ID
- **THEN** the file is removed from `memory/episodic/`
- **AND** the system returns `:ok`

#### Scenario: Delete a non-existent episode

- **WHEN** `delete/2` is called with an ID that does not correspond to any file
- **THEN** the system returns `{:error, :not_found}`

### Requirement: Search episodic memory entries

The system SHALL search episodic memory entries by text query across frontmatter and body content. The search SHALL be case-insensitive. Metadata filters (type, outcome, tags) SHALL be applied before text search. Results SHALL be sorted by timestamp descending.

#### Scenario: Search by text in summary

- **WHEN** `search/3` is called with query `"deploy"` and an episode has summary `"Fixed deployment pipeline"`
- **THEN** that episode is included in the results

#### Scenario: Search by text in body

- **WHEN** `search/3` is called with query `"docker"` and an episode has body content containing `"restarted the Docker container"`
- **THEN** that episode is included in the results

#### Scenario: Case-insensitive search

- **WHEN** `search/3` is called with query `"ELIXIR"`
- **THEN** episodes containing `"elixir"`, `"Elixir"`, or `"ELIXIR"` in their content are all matched

#### Scenario: Combined text and metadata filters

- **WHEN** `search/3` is called with query `"crash"` and `type: "error_encountered"`
- **THEN** only episodes with type `"error_encountered"` that also contain `"crash"` in their content are returned

#### Scenario: Empty query acts as filtered list

- **WHEN** `search/3` is called with an empty query string and filter options
- **THEN** the system returns episodes matching the metadata filters without text matching (same as `list/2`)

#### Scenario: Search respects limit

- **WHEN** `search/3` is called with `limit: 3`
- **THEN** at most 3 results are returned
