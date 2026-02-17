## ADDED Requirements

### Requirement: RecordEpisode creates a structured episodic memory entry

The `RecordEpisode` action SHALL create a new episode file in `memory/episodic/` with auto-generated ID and timestamp, structured frontmatter, and a markdown body assembled from the provided observation, approach, result, and lessons parameters.

#### Scenario: Record a successful task completion episode

- **WHEN** `RecordEpisode` is called with `type: "task_completion"`, `summary: "Fixed login bug"`, `outcome: "success"`, `observation: "Login page returned 500"`, `approach: "Checked server logs"`, `result: "Found null pointer in auth handler"`
- **THEN** a new markdown file SHALL be created in `memory/episodic/`
- **AND** the frontmatter SHALL contain an auto-generated `id` (UUID7)
- **AND** the frontmatter SHALL contain an auto-generated `timestamp` (ISO 8601)
- **AND** the frontmatter SHALL contain `type: "task_completion"` and `outcome: "success"`
- **AND** the body SHALL contain `## Observation`, `## Approach`, `## Result`, and `## Lessons` sections
- **AND** the return value SHALL include `%{episode: ..., message: "Episode recorded: Fixed login bug"}`

#### Scenario: Summary is truncated to 200 characters

- **WHEN** `RecordEpisode` is called with a `summary` longer than 200 characters
- **THEN** the stored summary SHALL be truncated to 200 characters

#### Scenario: Optional fields use defaults

- **WHEN** `RecordEpisode` is called without `tags`, `entities_involved`, or `lessons`
- **THEN** `tags` SHALL default to an empty list
- **AND** `entities_involved` SHALL default to an empty list
- **AND** `lessons` SHALL default to an empty string

#### Scenario: Invalid episode type is rejected

- **WHEN** `RecordEpisode` is called with `type: "invalid_type"`
- **THEN** the action SHALL return an error

---

### Requirement: SearchEpisodes finds episodes by text and filters

The `SearchEpisodes` action SHALL search the episodic memory store by text query across frontmatter and body content, with optional filters for tags, type, outcome, and a result limit.

#### Scenario: Search by text query

- **WHEN** `SearchEpisodes` is called with `query: "login bug"`
- **AND** one episode's body contains the text "login bug"
- **THEN** the result SHALL include that episode in the `episodes` list
- **AND** the result SHALL include a `count` matching the number of results

#### Scenario: Search with tag filter

- **WHEN** `SearchEpisodes` is called with `tags: ["auth"]`
- **AND** two episodes have the "auth" tag and one does not
- **THEN** the result SHALL include only the two tagged episodes

#### Scenario: Search with outcome filter

- **WHEN** `SearchEpisodes` is called with `outcome: "failure"`
- **THEN** the result SHALL include only episodes with `outcome: "failure"`

#### Scenario: Search respects limit

- **WHEN** `SearchEpisodes` is called with `limit: 3`
- **AND** 10 episodes match the query
- **THEN** the result SHALL contain at most 3 episodes

#### Scenario: Search with no matches returns empty list

- **WHEN** `SearchEpisodes` is called with `query: "nonexistent topic"`
- **AND** no episodes match
- **THEN** the result SHALL be `%{episodes: [], count: 0}`

---

### Requirement: ReadEpisode retrieves a single episode by ID

The `ReadEpisode` action SHALL read a specific episode from the episodic store and return its frontmatter and full body content.

#### Scenario: Read an existing episode

- **WHEN** `ReadEpisode` is called with `id: "<valid-episode-id>"`
- **AND** an episode with that ID exists in `memory/episodic/`
- **THEN** the result SHALL include `%{frontmatter: ..., body: ...}`
- **AND** `frontmatter` SHALL be a map containing the episode's metadata
- **AND** `body` SHALL be the full markdown body of the episode

#### Scenario: Read a nonexistent episode

- **WHEN** `ReadEpisode` is called with `id: "nonexistent-id"`
- **AND** no episode with that ID exists
- **THEN** the action SHALL return `{:error, :not_found}` or equivalent error tuple

---

### Requirement: ListEpisodes returns recent episodes with optional filters

The `ListEpisodes` action SHALL list episodes from the episodic store, sorted by timestamp descending (most recent first), with optional type and outcome filters and a configurable limit.

#### Scenario: List recent episodes

- **WHEN** `ListEpisodes` is called with default parameters
- **THEN** the result SHALL include up to 20 episodes sorted by timestamp descending
- **AND** the result SHALL include a `count` field

#### Scenario: List with type filter

- **WHEN** `ListEpisodes` is called with `type: "problem_solved"`
- **THEN** the result SHALL include only episodes with `type: "problem_solved"`

#### Scenario: List with custom limit

- **WHEN** `ListEpisodes` is called with `limit: 5`
- **THEN** the result SHALL contain at most 5 episodes

#### Scenario: List from empty store

- **WHEN** `ListEpisodes` is called
- **AND** no episodes exist in the store
- **THEN** the result SHALL be `%{episodes: [], count: 0}`

---

### Requirement: Episodic actions are registered as agent tools

All four episodic memory actions SHALL be listed in the `tools:` configuration of `Goodwizard.Agent` so the LLM can invoke them during the ReAct loop.

#### Scenario: Agent has episodic tools available

- **WHEN** the agent is initialized
- **THEN** the tool list SHALL include `RecordEpisode`, `SearchEpisodes`, `ReadEpisode`, and `ListEpisodes`
