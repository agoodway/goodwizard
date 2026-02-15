## ADDED Requirements

### Requirement: Schema versioning
Each schema SHALL include a top-level `version` integer field. The version starts at `1` for new schemas and increments by `1` on each update.

#### Scenario: Initial schema version
- **WHEN** a new entity type schema is created
- **THEN** its `version` field SHALL be `1`

#### Scenario: Schema version increments on update
- **WHEN** a schema is updated from version N
- **THEN** the new schema's `version` field SHALL be N+1

#### Scenario: Schema version mismatch rejected
- **WHEN** a save-schema request provides a schema with a version that is not exactly current version + 1
- **THEN** the system SHALL return an error indicating the version mismatch

### Requirement: Schema history archival
The system SHALL archive previous schema versions when a schema is updated. Archived schemas SHALL be stored in `brain/schemas/history/`.

#### Scenario: Schema archived on update
- **WHEN** a schema for "people" at version 1 is updated to version 2
- **THEN** the system SHALL copy the current schema to `brain/schemas/history/people_v1.json` before overwriting

#### Scenario: History directory auto-created
- **WHEN** a schema is updated and `brain/schemas/history/` does not exist
- **THEN** the system SHALL create the directory before archiving

### Requirement: Schema migration definitions
When updating a schema, a migration definition SHALL be provided describing how to transform existing entity data from the old schema to the new schema. Migration definitions SHALL be stored in `brain/schemas/migrations/`.

#### Scenario: Migration definition stored on schema update
- **WHEN** a "people" schema is updated from version 1 to version 2 with a migration definition
- **THEN** the migration SHALL be stored at `brain/schemas/migrations/people_v1_to_v2.json`

#### Scenario: Migration definition structure
- **WHEN** a migration definition is provided
- **THEN** it SHALL contain `from_version` (integer), `to_version` (integer), and `operations` (array of operation objects)

#### Scenario: Supported migration operations
- **WHEN** a migration definition includes operations
- **THEN** each operation SHALL be one of:
  - `add_field`: adds a field with a default value (`{"op": "add_field", "field": "<name>", "default": <value>}`)
  - `rename_field`: renames a field (`{"op": "rename_field", "from": "<old>", "to": "<new>"}`)
  - `remove_field`: removes a field (`{"op": "remove_field", "field": "<name>"}`)
  - `set_default`: sets a default for a field only if absent (`{"op": "set_default", "field": "<name>", "value": <value>}`)

### Requirement: Migration definition required for schema updates
When updating an existing schema, a migration definition SHALL be provided. New schemas (no existing schema) do not require a migration.

#### Scenario: Update schema requires migration
- **WHEN** a save-schema request is made for an existing entity type
- **THEN** the new schema's `version` field SHALL be exactly one greater than the current schema's `version`
- **AND** a migration definition SHALL be provided

#### Scenario: Update schema without migration rejected
- **WHEN** a save-schema request is made for an existing entity type without a migration definition
- **THEN** the system SHALL return an error indicating a migration definition is required

## MODIFIED Requirements

### Requirement: SaveSchema handles versioning and archival on update
When `SaveSchema` is called for an entity type that already has a schema, the system SHALL archive the current schema and store the migration definition before overwriting.

#### Scenario: Update existing schema with migration
- **WHEN** a save-schema request is made for an entity type that already has a schema
- **THEN** the system SHALL archive the current schema to `brain/schemas/history/<entity_type>_v<N>.json`, store the migration definition to `brain/schemas/migrations/<entity_type>_v<N>_to_v<N+1>.json`, and overwrite the current schema file with the new schema

### Requirement: Entity migration execution
The system SHALL provide a `MigrateEntities` action that applies a stored migration to all entities of a given type.

#### Scenario: Migrate entities
- **WHEN** a migrate request is made with entity_type "people" from version 1 to version 2
- **THEN** the system SHALL read the migration from `brain/schemas/migrations/people_v1_to_v2.json`, apply each operation to every entity's frontmatter, validate against the new schema, and write the updated files

#### Scenario: Migration updates timestamps
- **WHEN** an entity is migrated
- **THEN** its `updated_at` field SHALL be set to the current UTC time

#### Scenario: Migration dry run
- **WHEN** a migrate request is made with `dry_run: true`
- **THEN** the system SHALL report the changes that would be applied to each entity without writing any files

#### Scenario: Migration result summary
- **WHEN** a migration completes
- **THEN** the system SHALL return a summary with: total entities scanned, entities migrated, entities skipped (already valid), and entities with errors

#### Scenario: Migration validation failure
- **WHEN** a migrated entity fails validation against the new schema
- **THEN** the system SHALL skip that entity, include it in the error list with the validation message, and continue migrating remaining entities

#### Scenario: Migration for non-existent version pair
- **WHEN** a migrate request is made for a version pair with no stored migration definition
- **THEN** the system SHALL return an error indicating no migration exists for that version pair
