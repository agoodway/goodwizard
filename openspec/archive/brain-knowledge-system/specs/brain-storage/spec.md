## ADDED Requirements

### Requirement: Entity files use markdown with YAML frontmatter
The system SHALL store each entity as a markdown file where structured data is serialized as YAML frontmatter and the file body contains freeform notes. The frontmatter SHALL be delimited by `---` on its own line.

#### Scenario: Reading an entity file
- **WHEN** the system reads an entity file from disk
- **THEN** it SHALL parse the YAML frontmatter into a map and return the body as a separate string field

#### Scenario: Writing an entity file
- **WHEN** the system writes an entity to disk
- **THEN** it SHALL serialize the entity's structured fields as YAML frontmatter delimited by `---` lines, followed by the freeform body content

#### Scenario: Entity file with no body content
- **WHEN** an entity has no freeform notes
- **THEN** the file SHALL still contain valid YAML frontmatter with an empty body after the closing `---`

### Requirement: Entity files are organized by type in brain directory
The system SHALL store entity files in `brain/<entity_type>/` subdirectories within the workspace. Each entity type SHALL have its own subdirectory.

#### Scenario: Creating an entity creates the correct file path
- **WHEN** a "people" entity is created and assigned id "k3g7qae5"
- **THEN** the file SHALL be written to `brain/people/k3g7qae5.md`

#### Scenario: Brain directory is auto-created
- **WHEN** an entity is created and the `brain/<entity_type>/` directory does not exist
- **THEN** the system SHALL create the directory before writing the file

### Requirement: Entity CRUD operations
The system SHALL provide create, read, update, delete, and list operations for entities.

#### Scenario: Create entity
- **WHEN** a create request is made with entity_type, valid data, and optional body
- **THEN** the system SHALL validate the data against the entity type's schema, generate a file with YAML frontmatter, write it to the correct path, and return the created entity

#### Scenario: Create entity with duplicate ID
- **WHEN** a create request is made and a file with the same ID already exists
- **THEN** the system SHALL return an error indicating the entity already exists

#### Scenario: Read entity
- **WHEN** a read request is made with entity_type and entity ID
- **THEN** the system SHALL read the file, parse frontmatter and body, and return the entity data

#### Scenario: Read non-existent entity
- **WHEN** a read request is made for an entity that does not exist
- **THEN** the system SHALL return an error indicating the entity was not found

#### Scenario: Update entity
- **WHEN** an update request is made with entity_type, entity ID, and new data
- **THEN** the system SHALL validate the merged data against the schema, update the `updated_at` timestamp, and overwrite the file

#### Scenario: Delete entity
- **WHEN** a delete request is made with entity_type and entity ID
- **THEN** the system SHALL remove the entity file from disk and return success

#### Scenario: Delete non-existent entity
- **WHEN** a delete request is made for an entity that does not exist
- **THEN** the system SHALL return an error indicating the entity was not found

#### Scenario: List entities
- **WHEN** a list request is made with entity_type
- **THEN** the system SHALL scan the entity type directory, parse all entity files, and return a list of entity summaries (id, name/title, tags)

#### Scenario: List entities for empty directory
- **WHEN** a list request is made for an entity type with no entities
- **THEN** the system SHALL return an empty list

### Requirement: Entity IDs are generated using Sqids
The system SHALL generate a short, unique ID for each entity using the Sqids library. IDs SHALL be encoded from a monotonic counter stored in `brain/.counter`. The ID SHALL be used as the filename (without extension).

#### Scenario: ID auto-generated on creation
- **WHEN** an entity is created without an explicit `id` field
- **THEN** the system SHALL increment the counter in `brain/.counter`, encode it via Sqids (lowercase alphanumeric, min length 8), and use the result as the entity's `id`
- **AND** the file SHALL be named `<sqid>.md` (e.g., "k3g7qae5.md")

#### Scenario: Counter file initialization
- **WHEN** an entity is created and `brain/.counter` does not exist
- **THEN** the system SHALL create the file starting at counter value `0`

#### Scenario: Explicit ID provided
- **WHEN** an entity is created with an explicit `id` field that matches the Sqid pattern (lowercase alphanumeric, 6+ characters)
- **THEN** the system SHALL use the provided ID instead of generating one

#### Scenario: Invalid ID format rejected
- **WHEN** an entity is created with an explicit `id` field that does not match the Sqid pattern
- **THEN** the system SHALL return an error indicating the ID format is invalid

### Requirement: Entity references use entity-type/sqid format
Fields that reference another entity SHALL use the string format `<entity_type>/<sqid>` (e.g., `"companies/x9rku2dq"`). This format encodes both the target entity type and its ID in a single value.

#### Scenario: Single entity reference field
- **WHEN** a people entity references a company
- **THEN** the `company` field SHALL contain a string like `"companies/x9rku2dq"`

#### Scenario: Array of entity references
- **WHEN** an events entity lists attendees
- **THEN** the `attendees` field SHALL contain an array of strings like `["people/k3g7qae5", "people/f1cspw92"]`

#### Scenario: Polymorphic entity references
- **WHEN** a notes entity has related_to references of mixed types
- **THEN** the `related_to` field SHALL contain an array of strings like `["people/k3g7qae5", "events/bg6sp8yz"]`

#### Scenario: Reference format validation
- **WHEN** an entity reference field is provided
- **THEN** the system SHALL validate the value matches the pattern `<entity_type>/<sqid>` where entity_type is a known type and sqid matches `[a-z0-9]{6,}`

### Requirement: Common fields across all entities
Every entity SHALL include `id`, `created_at`, `updated_at`, and optional `tags` fields. The `created_at` field SHALL be set on creation. The `updated_at` field SHALL be set on creation and updated on every modification.

#### Scenario: Timestamps set on creation
- **WHEN** a new entity is created
- **THEN** `created_at` and `updated_at` SHALL both be set to the current UTC time in ISO 8601 format

#### Scenario: Updated_at changes on update
- **WHEN** an existing entity is updated
- **THEN** `updated_at` SHALL be set to the current UTC time, while `created_at` SHALL remain unchanged

### Requirement: Path safety for brain operations
The system SHALL validate all paths to prevent directory traversal attacks. Entity IDs and entity type names SHALL be validated to contain only alphanumeric characters, hyphens, and underscores.

#### Scenario: Path traversal in entity ID rejected
- **WHEN** an entity operation is requested with an ID containing `..` or `/`
- **THEN** the system SHALL return an error and NOT perform any file operation

#### Scenario: Path traversal in entity type rejected
- **WHEN** an entity operation is requested with an entity_type containing `..` or `/`
- **THEN** the system SHALL return an error and NOT perform any file operation
