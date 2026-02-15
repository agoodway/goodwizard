## ADDED Requirements

### Requirement: Tasklists schema definition
The system SHALL include a `tasklists` JSON Schema with required fields `id` and `title`, and optional fields `description`, `status`, and `tasks`.

#### Scenario: Schema has required fields
- **WHEN** the `tasklists` schema is loaded
- **THEN** it SHALL require `id` and `title` fields

#### Scenario: Status field uses enum
- **WHEN** a tasklist entity is created with a `status` value
- **THEN** the value MUST be one of: `active`, `completed`, `archived`

#### Scenario: Tasks field references tasks entities
- **WHEN** a tasklist entity includes a `tasks` field
- **THEN** each item MUST match the pattern `^tasks/[a-z0-9]{8,}$`

### Requirement: Tasklists included in default seeds
The `tasklists` type SHALL be included in `Seeds.entity_types()` and seeded automatically when the brain is initialized for the first time.

#### Scenario: Fresh workspace seeds tasklists schema
- **WHEN** `Brain.ensure_initialized/1` runs on a workspace with no schemas
- **THEN** a `tasklists.json` schema file SHALL be created in `brain/schemas/`

#### Scenario: Setup task creates tasklists directory
- **WHEN** `mix goodwizard.setup` runs
- **THEN** a `brain/tasklists/` directory SHALL be created in the workspace

### Requirement: CRUD operations work with tasklists
The existing generic brain CRUD operations SHALL work with the `tasklists` entity type without modification.

#### Scenario: Create a tasklist
- **WHEN** `Brain.create(workspace, "tasklists", %{"title" => "My List"}, "")` is called
- **THEN** a new entity file SHALL be written to `brain/tasklists/<id>.md`

#### Scenario: List tasklists
- **WHEN** `Brain.list(workspace, "tasklists")` is called
- **THEN** all tasklist entities SHALL be returned
