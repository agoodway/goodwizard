## ADDED Requirements

### Requirement: Reference field extraction from schema
The system SHALL provide a `Brain.References.ref_fields/1` function that extracts reference field metadata from a resolved JSON Schema.

#### Scenario: Single entity ref field detected
- **WHEN** a schema has a property with `"type" => "string"` and `"pattern"` matching `^<type>/[a-z0-9]{8,}$`
- **THEN** `ref_fields/1` SHALL return it as a single ref with the target type extracted

#### Scenario: Entity ref list field detected
- **WHEN** a schema has a property with `"type" => "array"` and `"items"."pattern"` matching `^<type>/[a-z0-9]{8,}$`
- **THEN** `ref_fields/1` SHALL return it as a list ref with the target type extracted

#### Scenario: Non-reference fields ignored
- **WHEN** a schema has properties without entity reference patterns
- **THEN** `ref_fields/1` SHALL not include them in the result

### Requirement: Stale reference cleaning on read
The system SHALL remove stale entity references from data returned by `Brain.read/3` and `Brain.list/2`.

#### Scenario: Single ref pointing to deleted entity
- **WHEN** an entity has a single ref field (e.g. `"company" => "companies/abcd1234"`) and the referenced entity does not exist on disk
- **THEN** the returned data SHALL have that field set to `nil`

#### Scenario: Ref list with mix of valid and stale refs
- **WHEN** an entity has a ref list field containing both existing and deleted entity references
- **THEN** the returned data SHALL include only the existing references, with stale ones removed

#### Scenario: All references valid
- **WHEN** all entity references in a read entity point to existing entities
- **THEN** the returned data SHALL be unchanged

#### Scenario: File on disk not modified
- **WHEN** stale references are cleaned during a read operation
- **THEN** the entity file on disk SHALL NOT be modified

### Requirement: Explicit reference validation
The system SHALL provide a `Brain.References.validate/3` function that returns a list of stale references without modifying data.

#### Scenario: Validate entity with stale references
- **WHEN** `validate/3` is called for an entity with stale references
- **THEN** it SHALL return a list of `{field_name, stale_ref}` tuples

#### Scenario: Validate entity with no stale references
- **WHEN** `validate/3` is called for an entity where all references exist
- **THEN** it SHALL return an empty list

### Requirement: Async stale reference sweep on delete
After a successful entity deletion, the system SHALL spawn an async task that scans brain files for references to the deleted entity and rewrites affected files to remove them.

#### Scenario: Delete triggers async sweep
- **WHEN** `Brain.delete/3` successfully removes an entity
- **THEN** it SHALL spawn an async task to sweep stale references and return `:ok` immediately without waiting for the sweep

#### Scenario: Sweep removes single ref to deleted entity
- **WHEN** the sweep finds an entity with a single ref field pointing to the deleted entity
- **THEN** it SHALL rewrite that entity's file with the ref field set to nil

#### Scenario: Sweep removes deleted entity from ref list
- **WHEN** the sweep finds an entity with a ref list containing the deleted entity's reference
- **THEN** it SHALL rewrite that entity's file with the stale reference removed from the list

#### Scenario: Sweep only scans types that reference the deleted type
- **WHEN** the sweep runs after deleting a `tasks` entity
- **THEN** it SHALL only scan entity types whose schema has ref fields pointing at `tasks`, not all types

#### Scenario: Sweep failure does not affect delete result
- **WHEN** the async sweep encounters an error (e.g. file permission issue)
- **THEN** the original delete SHALL have already returned `:ok` and the error SHALL be logged
