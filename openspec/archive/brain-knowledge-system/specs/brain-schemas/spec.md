## ADDED Requirements

### Requirement: JSON Schema files stored in brain/schemas directory
The system SHALL store JSON Schema files in `brain/schemas/` within the workspace. Each entity type SHALL have a corresponding `<entity_type>.json` schema file.

#### Scenario: Schema file location
- **WHEN** an entity type "people" exists
- **THEN** its schema SHALL be stored at `brain/schemas/people.json`

#### Scenario: Schemas directory auto-created
- **WHEN** a schema is saved and the `brain/schemas/` directory does not exist
- **THEN** the system SHALL create the directory before writing the schema file

### Requirement: Schema validation using ex_json_schema
The system SHALL use `ex_json_schema` to validate entity data against JSON Schema draft 7. Schemas SHALL be resolved once via `ExJsonSchema.Schema.resolve/1` and cached for repeated validation.

#### Scenario: Valid entity data passes validation
- **WHEN** entity data conforms to the entity type's JSON Schema
- **THEN** validation SHALL return `:ok`

#### Scenario: Invalid entity data fails validation
- **WHEN** entity data does not conform to the entity type's JSON Schema (e.g., missing required field)
- **THEN** validation SHALL return an error with a descriptive message indicating which fields failed

#### Scenario: Schema resolution happens once
- **WHEN** a schema is loaded for the first time
- **THEN** the system SHALL resolve it via `ExJsonSchema.Schema.resolve/1` and the resolved schema SHALL be reusable for subsequent validations

### Requirement: Initial entity type schemas
The system SHALL ship with JSON Schema definitions for 6 entity types: people, places, events, notes, tasks, companies. Each schema SHALL include the common fields (id, created_at, updated_at, tags) plus type-specific fields.

#### Scenario: People schema fields
- **WHEN** the people schema is loaded
- **THEN** it SHALL require `name` (string) and support optional fields: `email` (string, email format), `phone` (string), `company` (string, entity reference to companies), `role` (string), `notes` (array of strings, entity references to notes)

#### Scenario: Places schema fields
- **WHEN** the places schema is loaded
- **THEN** it SHALL require `name` (string) and support optional fields: `address` (string), `city` (string), `state` (string), `country` (string), `coordinates` (object with lat/lng numbers), `notes` (array of strings, entity references to notes)

#### Scenario: Events schema fields
- **WHEN** the events schema is loaded
- **THEN** it SHALL require `title` (string) and `date` (string, date-time format), and support optional fields: `location` (string, entity reference to places), `attendees` (array of strings, entity references to people), `description` (string), `notes` (array of strings, entity references to notes)

#### Scenario: Notes schema fields
- **WHEN** the notes schema is loaded
- **THEN** it SHALL require `title` (string) and support optional fields: `topic` (string), `related_to` (array of strings, polymorphic entity references)

#### Scenario: Tasks schema fields
- **WHEN** the tasks schema is loaded
- **THEN** it SHALL require `title` (string) and support optional fields: `status` (string, enum: "pending", "in_progress", "done", "cancelled"), `priority` (string, enum: "low", "medium", "high"), `due_date` (string, date-time format), `assignee` (string, entity reference to people), `notes` (array of strings, entity references to notes)

#### Scenario: Companies schema fields
- **WHEN** the companies schema is loaded
- **THEN** it SHALL require `name` (string) and support optional fields: `domain` (string), `industry` (string), `size` (string), `location` (string), `contacts` (array of strings, entity references to people), `notes` (array of strings, entity references to notes)

#### Scenario: Notes many-to-many relationship
- **WHEN** any non-notes entity type schema is loaded
- **THEN** it SHALL include a `notes` field (array of entity references to notes)
- **AND** the notes schema SHALL include a `related_to` field (array of polymorphic entity references) forming the inverse side of the relationship

### Requirement: Schema CRUD operations
The system SHALL support reading, creating, updating, and listing schemas.

#### Scenario: Get schema for entity type
- **WHEN** a get-schema request is made with an entity type name
- **THEN** the system SHALL read and return the JSON Schema from `brain/schemas/<entity_type>.json`

#### Scenario: Get schema for non-existent type
- **WHEN** a get-schema request is made for an entity type with no schema file
- **THEN** the system SHALL return an error indicating the schema was not found

#### Scenario: Save schema for new entity type
- **WHEN** a save-schema request is made with an entity type name and a valid JSON Schema
- **THEN** the system SHALL validate the schema is valid JSON Schema, write it to `brain/schemas/<entity_type>.json`, and create the entity type directory at `brain/<entity_type>/`

#### Scenario: Save invalid JSON Schema
- **WHEN** a save-schema request is made with content that is not a valid JSON Schema
- **THEN** the system SHALL return an error indicating the schema is invalid

#### Scenario: Update existing schema
- **WHEN** a save-schema request is made for an entity type that already has a schema
- **THEN** the system SHALL overwrite the existing schema file with the new schema

#### Scenario: List entity types
- **WHEN** a list-entity-types request is made
- **THEN** the system SHALL scan `brain/schemas/` for `.json` files and return the entity type names (filenames without extension)

### Requirement: Creating new entity types at runtime
The system SHALL allow creating new entity types by saving a new JSON Schema. When a new schema is saved, the corresponding entity type directory SHALL be created automatically.

#### Scenario: Create new entity type
- **WHEN** a save-schema request is made for entity type "projects" with a valid schema
- **THEN** the system SHALL write `brain/schemas/projects.json` and create `brain/projects/` directory
- **THEN** the new entity type SHALL be immediately available for CRUD operations

#### Scenario: New entity type schema must include common fields
- **WHEN** a new schema is saved
- **THEN** the schema SHALL include `id` (string, required, sqid pattern), `created_at` (string), `updated_at` (string), and `tags` (array of strings) properties — either defined directly or inherited from a shared definition

#### Scenario: New entity type schema must include version
- **WHEN** a new schema is saved
- **THEN** the schema SHALL include a `version` field set to `1`
