## ADDED Requirements

### Requirement: Workspace spec scanning
The system SHALL scan `workspace/openspec/` at agent startup and build an index of all projects, capabilities, and spec files.

#### Scenario: Startup with specs present
- **WHEN** the agent starts and `workspace/openspec/` contains one or more project directories with spec files
- **THEN** the plugin builds an index mapping each project to its capabilities and requirement counts

#### Scenario: Startup with no specs directory
- **WHEN** the agent starts and `workspace/openspec/` does not exist
- **THEN** the plugin mounts successfully with an empty index and no error

#### Scenario: Startup with empty project
- **WHEN** the agent starts and a project directory exists under `workspace/openspec/` but contains no `specs/` subdirectory
- **THEN** the project is included in the index with zero capabilities

### Requirement: List projects
The system SHALL provide an action to list all projects in the workspace OpenSpec directory.

#### Scenario: Multiple projects exist
- **WHEN** the `list_projects` action is called
- **THEN** it returns a list of project names with their capability counts

#### Scenario: No projects exist
- **WHEN** the `list_projects` action is called and the openspec directory is empty
- **THEN** it returns an empty list

### Requirement: List capabilities for a project
The system SHALL provide an action to list capabilities (spec domains) within a specific project.

#### Scenario: Project with capabilities
- **WHEN** the `list_specs` action is called with a valid project name
- **THEN** it returns the list of capability names and their requirement counts for that project

#### Scenario: Unknown project
- **WHEN** the `list_specs` action is called with a project name that does not exist
- **THEN** it returns an error indicating the project was not found

### Requirement: List active changes for a project
The system SHALL provide an action to list active changes (non-archived) within a project.

#### Scenario: Project with active changes
- **WHEN** the `list_changes` action is called with a project that has changes in its `changes/` directory
- **THEN** it returns a list of change names, each with its artifact status (which artifacts exist)

#### Scenario: Project with no changes
- **WHEN** the `list_changes` action is called for a project with no `changes/` directory
- **THEN** it returns an empty list
