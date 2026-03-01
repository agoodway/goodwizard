## ADDED Requirements

### Requirement: Read a spec
The system SHALL provide an action to read the full content of a specific spec file by project and capability name.

#### Scenario: Valid spec exists
- **WHEN** the `read_spec` action is called with a valid project and capability name
- **THEN** it returns the full markdown content of `workspace/openspec/<project>/specs/<capability>/spec.md`

#### Scenario: Spec does not exist
- **WHEN** the `read_spec` action is called with a capability name that has no spec file
- **THEN** it returns an error indicating the spec was not found

#### Scenario: Path traversal attempt
- **WHEN** the `read_spec` action is called with a capability name containing `..` or `/`
- **THEN** it returns a validation error and does not access the filesystem

### Requirement: Read a change artifact
The system SHALL provide an action to read a specific artifact (proposal, design, tasks, or delta spec) from a change.

#### Scenario: Read proposal
- **WHEN** the `read_change_artifact` action is called with project, change name, and artifact "proposal"
- **THEN** it returns the content of `workspace/openspec/<project>/changes/<change>/proposal.md`

#### Scenario: Read delta spec
- **WHEN** the `read_change_artifact` action is called with project, change name, artifact "spec", and capability name
- **THEN** it returns the content of `workspace/openspec/<project>/changes/<change>/specs/<capability>/spec.md`

#### Scenario: Artifact does not exist
- **WHEN** the `read_change_artifact` action is called for an artifact that has not been created
- **THEN** it returns an error indicating the artifact was not found

### Requirement: Search across specs
The system SHALL provide an action to search for text patterns across all specs in a project or across all projects.

#### Scenario: Search within a single project
- **WHEN** the `search_specs` action is called with a query string and a project filter
- **THEN** it returns matching lines with file paths and line numbers from specs in that project only

#### Scenario: Search across all projects
- **WHEN** the `search_specs` action is called with a query string and no project filter
- **THEN** it returns matching lines from specs across all projects in the workspace

#### Scenario: No matches found
- **WHEN** the `search_specs` action is called with a query that matches no spec content
- **THEN** it returns an empty result set

### Requirement: Parse spec structure
The system SHALL extract structured data from spec files including requirement names, scenario names, and RFC 2119 keywords.

#### Scenario: Well-formed spec
- **WHEN** a spec file contains `### Requirement:` and `#### Scenario:` headers
- **THEN** the parser extracts requirement names, scenario names, and counts them

#### Scenario: Spec with RFC 2119 keywords
- **WHEN** a spec file contains SHALL, MUST, SHOULD, or MAY keywords
- **THEN** the parser identifies and counts normative requirements by strength
