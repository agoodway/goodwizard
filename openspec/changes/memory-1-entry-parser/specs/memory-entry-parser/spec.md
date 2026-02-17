## ADDED Requirements

### Requirement: Parse memory entry files

The system SHALL parse markdown files with YAML frontmatter into a `{frontmatter_map, body_string}` tuple. The frontmatter map SHALL use string keys. The body SHALL be the trimmed content after the closing `---` fence.

#### Scenario: Parse a well-formed entry

- **WHEN** a markdown string with valid YAML frontmatter between `---` fences is parsed
- **THEN** the system returns `{:ok, {map, body}}` where map contains the frontmatter fields as string keys
- **AND** the body is the trimmed content after the closing fence

#### Scenario: Parse an entry with empty body

- **WHEN** a markdown string has valid frontmatter but no content after the closing `---` fence
- **THEN** the system returns `{:ok, {map, ""}}` with an empty string for the body

#### Scenario: Reject content with no frontmatter

- **WHEN** a markdown string without `---` fences is parsed
- **THEN** the system returns `{:error, :missing_frontmatter}`

#### Scenario: Reject YAML anchors in frontmatter

- **WHEN** frontmatter contains YAML anchor (`&`) or alias (`*`) syntax
- **THEN** the system returns `{:error, :yaml_anchors_not_allowed}`

#### Scenario: Reject oversized frontmatter

- **WHEN** the frontmatter section exceeds 64 KB
- **THEN** the system returns `{:error, :frontmatter_too_large}`

#### Scenario: Reject oversized body

- **WHEN** the body section exceeds 1 MB
- **THEN** the system returns `{:error, :body_too_large}`

#### Scenario: Frontmatter keys are strings

- **WHEN** a valid entry is parsed
- **THEN** all keys in the returned frontmatter map SHALL be strings, not atoms

### Requirement: Serialize memory entry files

The system SHALL serialize a frontmatter map and body string into a markdown string with YAML frontmatter. The output SHALL be parseable by the parse function (roundtrip fidelity).

#### Scenario: Serialize a map with string values

- **WHEN** a map `%{"type" => "workflow", "summary" => "How to deploy"}` and body `"Step 1..."` are serialized
- **THEN** the output is a string with the map encoded as YAML between `---` fences followed by the body

#### Scenario: Serialize a map with list values

- **WHEN** a map contains a key with a list value like `%{"tags" => ["elixir", "deploy"]}`
- **THEN** the YAML output represents the list in inline format `[elixir, deploy]`

#### Scenario: Serialize handles special characters

- **WHEN** a frontmatter value contains YAML-special characters (colons, brackets, quotes)
- **THEN** the value is quoted in the YAML output to prevent parse ambiguity

#### Scenario: Roundtrip fidelity

- **WHEN** a frontmatter map and body are serialized and then parsed
- **THEN** the parsed result matches the original map and body

### Requirement: Episodic and procedural path helpers

The system SHALL provide path helper functions for constructing paths to episodic and procedural memory directories and individual entry files.

#### Scenario: Episodic directory path

- **WHEN** `episodic_dir/1` is called with a memory directory path
- **THEN** it returns the path with `/episodic` appended

#### Scenario: Procedural directory path

- **WHEN** `procedural_dir/1` is called with a memory directory path
- **THEN** it returns the path with `/procedural` appended

#### Scenario: Episode file path

- **WHEN** `episode_path/2` is called with a memory directory and an ID
- **THEN** it returns the path `<memory_dir>/episodic/<id>.md`

#### Scenario: Procedure file path

- **WHEN** `procedure_path/2` is called with a memory directory and an ID
- **THEN** it returns the path `<memory_dir>/procedural/<id>.md`

### Requirement: Memory subdirectory validation

The system SHALL validate that memory subdirectory names are within the allowed set (`episodic`, `procedural`). Arbitrary subdirectory names SHALL be rejected.

#### Scenario: Valid subdirectory name

- **WHEN** `validate_memory_subdir/2` is called with subdirectory name `"episodic"`
- **THEN** it returns `{:ok, path}` where path is the full subdirectory path

#### Scenario: Valid subdirectory name (procedural)

- **WHEN** `validate_memory_subdir/2` is called with subdirectory name `"procedural"`
- **THEN** it returns `{:ok, path}` where path is the full subdirectory path

#### Scenario: Invalid subdirectory name rejected

- **WHEN** `validate_memory_subdir/2` is called with subdirectory name `"../secrets"`
- **THEN** it returns `{:error, :invalid_subdir}`

#### Scenario: Unknown subdirectory name rejected

- **WHEN** `validate_memory_subdir/2` is called with subdirectory name `"custom"`
- **THEN** it returns `{:error, :invalid_subdir}`
