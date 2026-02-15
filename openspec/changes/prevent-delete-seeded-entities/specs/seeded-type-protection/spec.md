## ADDED Requirements

### Requirement: Seeded type identification

The system SHALL provide a `Brain.Seeds.seeded_type?/1` function that returns `true` when the given entity type name is in the canonical seeded types list (`Brain.Seeds.entity_types/0`), and `false` otherwise.

#### Scenario: Check a seeded type
- **WHEN** `Brain.Seeds.seeded_type?("people")` is called
- **THEN** it returns `true`

#### Scenario: Check a non-seeded type
- **WHEN** `Brain.Seeds.seeded_type?("widgets")` is called
- **THEN** it returns `false`

#### Scenario: All six seeded types are recognized
- **WHEN** `Brain.Seeds.seeded_type?/1` is called with each of `people`, `places`, `events`, `notes`, `tasks`, `companies`
- **THEN** it returns `true` for all six

### Requirement: Prevent deletion of seeded entity type schemas

The `DeleteEntity` action SHALL reject any request that would delete a seeded entity type's schema. When the `entity_type` parameter matches a seeded type and the operation targets the schema (not an individual entity), the action MUST return `{:error, "Cannot delete protected entity type: <type>"}`.

#### Scenario: Attempt to delete a seeded type schema via action
- **WHEN** `DeleteEntity` is called with `entity_type: "people"` targeting the schema
- **THEN** the action returns `{:error, "Cannot delete protected entity type: people"}`
- **AND** the schema file remains on disk

#### Scenario: Delete an individual entity within a seeded type
- **WHEN** `DeleteEntity` is called with `entity_type: "people"` and `id: "abcd1234"`
- **THEN** the entity is deleted normally
- **AND** no protection error is raised

#### Scenario: Delete an entity within a non-seeded custom type
- **WHEN** `DeleteEntity` is called with `entity_type: "widgets"` and `id: "efgh5678"`
- **THEN** the entity is deleted normally

### Requirement: Protected error type

The system SHALL use a distinct error atom `:protected_entity_type` when a deletion is rejected due to seeded type protection. The action layer SHALL format this into a human-readable error message.

#### Scenario: Error atom returned from guard
- **WHEN** a seeded type schema deletion is attempted
- **THEN** the guard returns `{:error, :protected_entity_type}`

#### Scenario: Action formats error for caller
- **WHEN** the action receives `{:error, :protected_entity_type}`
- **THEN** it returns `{:error, "Cannot delete protected entity type: <type>"}`
