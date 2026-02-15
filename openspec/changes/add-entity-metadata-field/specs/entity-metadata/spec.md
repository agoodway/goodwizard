## ADDED Requirements

### Requirement: All entity types include a required metadata field
Every brain entity type schema SHALL include a **required** `metadata` property defined as a JSON object where all keys are strings and all values are strings. The field SHALL be part of the shared base properties so that current and future entity types inherit it automatically. The `"metadata"` key SHALL appear in the `"required"` array of every entity type schema.

#### Scenario: Entity created with metadata
- **WHEN** an entity is created with a `metadata` map (e.g. `%{"source" => "import", "batch_id" => "42"}`)
- **THEN** the entity is stored with the provided `metadata` in its YAML frontmatter and the data passes schema validation

#### Scenario: Entity created without metadata defaults to empty map
- **WHEN** an entity is created without a `metadata` field in the input data
- **THEN** the system auto-initializes `metadata` to `%{}` and the entity is stored successfully with `metadata: {}` in frontmatter

#### Scenario: Entity metadata is updated
- **WHEN** an existing entity is updated with new `metadata` values
- **THEN** the `metadata` field in the stored entity reflects the merged update data

#### Scenario: Entity metadata cannot be removed via update
- **WHEN** an existing entity with metadata is updated with `metadata` set to `nil`
- **THEN** the existing metadata is preserved (the nil value is ignored)

#### Scenario: Non-string metadata values are rejected
- **WHEN** an entity is created or updated with a `metadata` value that is not a string (e.g. `%{"count" => 42}`)
- **THEN** schema validation fails with an error indicating the value type is invalid

### Requirement: Metadata field is defined in base properties and always required
The `metadata` property SHALL be defined in `Goodwizard.Brain.Seeds.base_properties/0`. The `build_schema/3` function SHALL automatically include `"metadata"` in the `"required"` array of every schema it builds. The JSON Schema definition SHALL be:

```json
{
  "type": "object",
  "additionalProperties": { "type": "string" },
  "description": "Arbitrary key-value string metadata"
}
```

#### Scenario: All seed schemas include metadata as required
- **WHEN** `Seeds.schema_for/1` is called for any of the 7 default entity types
- **THEN** the returned schema map contains `"metadata"` in its `"properties"` with the object/string-values definition AND `"metadata"` appears in the `"required"` array

#### Scenario: Custom entity types inherit required metadata
- **WHEN** a new entity type is created using `build_schema/3`
- **THEN** the resulting schema includes the `metadata` property in both `"properties"` and `"required"`

### Requirement: System auto-initializes metadata on entity creation
The `Goodwizard.Brain.create/4` function SHALL ensure every new entity has a `metadata` field. If the caller provides metadata, it SHALL be used. If not, the system SHALL default to an empty map `%{}`.

#### Scenario: Caller provides metadata on create
- **WHEN** `Brain.create/4` is called with `%{"name" => "Alice", "metadata" => %{"source" => "csv"}}`
- **THEN** the stored entity has `metadata` set to `%{"source" => "csv"}`

#### Scenario: Caller omits metadata on create
- **WHEN** `Brain.create/4` is called with `%{"name" => "Alice"}` (no metadata key)
- **THEN** the stored entity has `metadata` set to `%{}`

### Requirement: Metadata is protected from removal on update
The `Goodwizard.Brain.update/5` function SHALL prevent `metadata` from being set to `nil` or removed. If the update data does not include `metadata`, the existing value is preserved via the normal merge. If the update data includes `metadata: nil`, the nil value SHALL be dropped before merge.

#### Scenario: Update without metadata preserves existing
- **WHEN** an entity with `metadata: %{"source" => "csv"}` is updated with `%{"name" => "Bob"}` (no metadata key)
- **THEN** the entity retains `metadata: %{"source" => "csv"}`

#### Scenario: Update with nil metadata is ignored
- **WHEN** an entity with `metadata: %{"source" => "csv"}` is updated with `%{"metadata" => nil}`
- **THEN** the entity retains `metadata: %{"source" => "csv"}`

### Requirement: Metadata is excluded from action results
The `ReadEntity` and `ListEntities` brain actions SHALL strip the `metadata` field from entity data before returning results. Metadata MUST NOT appear in any data returned to the agent, ensuring it never flows into prompts or messages.

#### Scenario: ReadEntity excludes metadata
- **WHEN** `ReadEntity` reads an entity that has `metadata: %{"source" => "csv"}`
- **THEN** the returned `data` map does not contain a `"metadata"` key

#### Scenario: ListEntities excludes metadata
- **WHEN** `ListEntities` lists entities that have metadata fields
- **THEN** none of the returned entity `data` maps contain a `"metadata"` key
