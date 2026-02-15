## ADDED Requirements

### Requirement: Entity IDs are UUID v4
The system SHALL generate entity IDs as UUID v4 strings in the canonical lowercase format: `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx` (8-4-4-4-12 hex digits with hyphens). The `Goodwizard.Brain.Id` module SHALL provide `generate/1`, `valid?/1`, and `id_pattern/0` functions using UUID v4.

#### Scenario: Generate a new entity ID
- **WHEN** `Id.generate(workspace)` is called
- **THEN** it returns `{:ok, id}` where `id` is a valid UUID v4 string matching `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`

#### Scenario: Generated IDs are unique
- **WHEN** `Id.generate/1` is called multiple times
- **THEN** each returned ID is distinct

#### Scenario: Validate a UUID ID
- **WHEN** `Id.valid?/1` is called with a valid UUID v4 string
- **THEN** it returns `true`

#### Scenario: Reject a non-UUID ID
- **WHEN** `Id.valid?/1` is called with a sqids-format string (e.g. `"abcd1234"`) or other invalid format
- **THEN** it returns `false`

#### Scenario: ID pattern matches UUID format
- **WHEN** `Id.id_pattern/0` is called
- **THEN** it returns the regex string `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`

### Requirement: No counter file or file locking for ID generation
The system SHALL NOT use a monotonic counter file, file locking, or counter recovery logic for ID generation. UUID v4 generation SHALL be stateless with no filesystem dependencies.

#### Scenario: No counter file created
- **WHEN** an entity is created via `Brain.create/4`
- **THEN** no `brain/.counter` or `brain/.counter.lock` file is created or modified

### Requirement: Schema patterns use UUID format
All entity type schemas SHALL use UUID-format patterns for the `id` field and all cross-entity reference fields. The `Seeds` module SHALL define:
- ID property pattern: `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`
- Typed entity reference pattern (e.g. companies): `^companies/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`
- Polymorphic reference pattern: `^[a-z_]+/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`

#### Scenario: Seed schema ID field uses UUID pattern
- **WHEN** `Seeds.schema_for/1` is called for any entity type
- **THEN** the `id` property's `pattern` matches the UUID regex

#### Scenario: Typed entity reference uses UUID pattern
- **WHEN** `Seeds.schema_for("people")` is called
- **THEN** the `company` field's pattern is `^companies/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`

#### Scenario: Polymorphic reference uses UUID pattern
- **WHEN** `Seeds.schema_for("notes")` is called
- **THEN** the `related_to` items pattern is `^[a-z_]+/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`

#### Scenario: Entity created with UUID ID passes schema validation
- **WHEN** an entity is created via `Brain.create/4`
- **THEN** the generated UUID ID passes the schema's `id` pattern validation

### Requirement: sqids dependency is removed
The `sqids` hex package SHALL be removed from `mix.exs` dependencies. No code SHALL reference the `Sqids` module.

#### Scenario: No sqids in dependencies
- **WHEN** `mix.exs` deps are inspected
- **THEN** there is no entry for `:sqids`
