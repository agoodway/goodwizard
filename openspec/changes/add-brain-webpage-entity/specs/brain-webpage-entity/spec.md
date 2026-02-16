## ADDED Requirements

### Requirement: Webpages schema definition
The system SHALL include a `webpages` JSON Schema with required fields `id`, `title`, and `url`, and optional field `description`.

#### Scenario: Schema has required fields
- **WHEN** the `webpages` schema is loaded
- **THEN** it SHALL require `id`, `title`, and `url` fields

#### Scenario: URL field uses URI format
- **WHEN** a webpage entity is created with a `url` value
- **THEN** the value MUST conform to JSON Schema `format: uri`

#### Scenario: Description field is optional string
- **WHEN** a webpage entity is created without a `description` field
- **THEN** the entity SHALL be created successfully

### Requirement: Webpages included in default seeds
The `webpages` type SHALL be included in `Seeds.entity_types()` and seeded automatically when the brain is initialized for the first time.

#### Scenario: Fresh workspace seeds webpages schema
- **WHEN** `Brain.ensure_initialized/1` runs on a workspace with no schemas
- **THEN** a `webpages.json` schema file SHALL be created in `brain/schemas/`

#### Scenario: Setup task creates webpages directory
- **WHEN** `mix goodwizard.setup` runs
- **THEN** a `brain/webpages/` directory SHALL be created in the workspace

### Requirement: CRUD operations work with webpages
The existing generic brain CRUD operations SHALL work with the `webpages` entity type without modification.

#### Scenario: Create a webpage
- **WHEN** `Brain.create(workspace, "webpages", %{"title" => "Docs", "url" => "https://example.com"}, "")` is called
- **THEN** a new entity file SHALL be written to `brain/webpages/<id>.md`

#### Scenario: List webpages
- **WHEN** `Brain.list(workspace, "webpages")` is called
- **THEN** all webpage entities SHALL be returned

### Requirement: All other entity types can reference webpages
Every entity type except `webpages` SHALL include an optional `webpages` field that accepts a list of entity references to the `webpages` type.

#### Scenario: Base properties include webpages reference list
- **WHEN** any non-webpage entity schema is loaded (people, places, events, notes, tasks, companies, tasklists)
- **THEN** it SHALL include a `webpages` property of type array with items matching the UUIDv7 entity reference pattern `^webpages/[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`

#### Scenario: Webpages schema excludes self-reference
- **WHEN** the `webpages` schema is loaded
- **THEN** it SHALL NOT include a `webpages` property referencing itself

#### Scenario: Entity created with webpage references
- **WHEN** a `people` entity is created with `"webpages" => ["webpages/01953780-1a2b-7c3d-89ab-0123456789ab"]`
- **THEN** the entity SHALL be created successfully with the webpage references stored

#### Scenario: Entity created without webpage references
- **WHEN** a `companies` entity is created without a `webpages` field
- **THEN** the entity SHALL be created successfully (field is optional)
