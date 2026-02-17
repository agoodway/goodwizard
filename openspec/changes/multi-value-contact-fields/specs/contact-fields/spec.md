## ADDED Requirements

### Requirement: People schema supports multi-value contact fields

The people JSON Schema (`priv/workspace/brain/schemas/people.json`) SHALL define `emails`, `phones`, `addresses`, and `socials` as array-of-object properties, replacing the old scalar `email` and `phone` fields. The schema version SHALL be bumped to `2`.

#### Scenario: People schema defines emails as array of objects

- **WHEN** the people schema is loaded
- **THEN** the `emails` property SHALL be an array of objects with optional `type` (string) and required `value` (string, format: email)
- **AND** the old `email` scalar property SHALL NOT exist

#### Scenario: People schema defines phones as array of objects

- **WHEN** the people schema is loaded
- **THEN** the `phones` property SHALL be an array of objects with optional `type` (string) and required `value` (string)
- **AND** the old `phone` scalar property SHALL NOT exist

#### Scenario: People schema defines addresses as array of objects

- **WHEN** the people schema is loaded
- **THEN** the `addresses` property SHALL be an array of objects with optional fields: `type`, `street`, `city`, `state`, `zip`, `country` (all strings)

#### Scenario: People schema defines socials as array of objects

- **WHEN** the people schema is loaded
- **THEN** the `socials` property SHALL be an array of objects with optional `type` (string) and required `value` (string)

---

### Requirement: Companies schema supports multi-value contact fields

The companies JSON Schema (`priv/workspace/brain/schemas/companies.json`) SHALL define `emails`, `phones`, `addresses`, and `socials` as array-of-object properties, replacing the old scalar `location` field. The schema version SHALL be bumped to `2`.

#### Scenario: Companies schema defines emails as array of objects

- **WHEN** the companies schema is loaded
- **THEN** the `emails` property SHALL be an array of objects with optional `type` (string) and required `value` (string, format: email)

#### Scenario: Companies schema defines phones as array of objects

- **WHEN** the companies schema is loaded
- **THEN** the `phones` property SHALL be an array of objects with optional `type` (string) and required `value` (string)

#### Scenario: Companies schema defines addresses as array of objects

- **WHEN** the companies schema is loaded
- **THEN** the `addresses` property SHALL be an array of objects with optional fields: `type`, `street`, `city`, `state`, `zip`, `country` (all strings)
- **AND** the old `location` scalar property SHALL NOT exist

#### Scenario: Companies schema defines socials as array of objects

- **WHEN** the companies schema is loaded
- **THEN** the `socials` property SHALL be an array of objects with optional `type` (string) and required `value` (string)

---

### Requirement: SchemaMapper handles array-of-object properties

`Goodwizard.Brain.SchemaMapper.map_type/1` SHALL map JSON Schema properties with `type: "array"` and `items.type: "object"` to the NimbleOptions type `{:list, :map}`.

#### Scenario: Array of objects maps to list of maps

- **WHEN** `SchemaMapper.map_type/1` receives `%{"type" => "array", "items" => %{"type" => "object"}}`
- **THEN** it SHALL return `{:list, :map}`

#### Scenario: Array of objects generates descriptive documentation

- **WHEN** `SchemaMapper.build_doc/1` receives an array-of-object property with a `description`
- **THEN** it SHALL include the description in the generated doc string

---

### Requirement: Generated tools accept structured contact data

`ToolGenerator`-generated create and update actions for people and companies SHALL accept `emails`, `phones`, `addresses`, and `socials` parameters as lists of maps.

#### Scenario: Create person with multiple emails

- **WHEN** the generated `create_person` action is called with `emails: [%{"type" => "work", "value" => "work@example.com"}, %{"type" => "personal", "value" => "me@example.com"}]`
- **THEN** the entity SHALL be created with both email entries stored in the `emails` array

#### Scenario: Update company with addresses

- **WHEN** the generated `update_company` action is called with `addresses: [%{"type" => "hq", "street" => "123 Main St", "city" => "Austin", "state" => "TX"}]`
- **THEN** the entity SHALL be updated with the address entry in the `addresses` array

#### Scenario: Create entity with empty contact arrays

- **WHEN** a create action is called without providing contact field arrays
- **THEN** the entity SHALL be created successfully with those fields absent (not empty arrays)

---

### Requirement: Entity YAML serialization round-trips arrays of objects

`Goodwizard.Brain.Entity.serialize/2` and `Entity.parse/1` SHALL correctly round-trip arrays of objects in YAML frontmatter without data loss.

#### Scenario: Serialize and parse entity with contact arrays

- **WHEN** an entity with `emails: [%{"type" => "work", "value" => "a@b.com"}]` is serialized and then parsed
- **THEN** the parsed data SHALL contain `"emails" => [%{"type" => "work", "value" => "a@b.com"}]`

#### Scenario: Serialize entity with nested address objects

- **WHEN** an entity with `addresses: [%{"type" => "office", "street" => "123 Main", "city" => "Austin"}]` is serialized and then parsed
- **THEN** the parsed data SHALL preserve all address sub-fields

---

### Requirement: Migration task converts existing scalar contact fields

A Mix task `mix goodwizard.migrate_contacts` SHALL migrate existing entity files from scalar contact fields to the new array-of-object format.

#### Scenario: Migrate person with scalar email and phone

- **WHEN** a person entity file has `email: "user@example.com"` and `phone: "+1234567890"` in frontmatter
- **AND** `mix goodwizard.migrate_contacts` is run
- **THEN** the entity SHALL be rewritten with `emails: [%{"value" => "user@example.com"}]` and `phones: [%{"value" => "+1234567890"}]`
- **AND** the old `email` and `phone` fields SHALL be removed

#### Scenario: Migrate company with scalar location

- **WHEN** a company entity file has `location: "Austin, TX"` in frontmatter
- **AND** `mix goodwizard.migrate_contacts` is run
- **THEN** the entity SHALL be rewritten with `addresses: [%{"value" => "Austin, TX"}]`
- **AND** the old `location` field SHALL be removed

#### Scenario: Skip entities without old fields

- **WHEN** an entity file has no `email`, `phone`, or `location` scalar fields
- **AND** `mix goodwizard.migrate_contacts` is run
- **THEN** the entity file SHALL NOT be modified

#### Scenario: Report migration results

- **WHEN** `mix goodwizard.migrate_contacts` completes
- **THEN** it SHALL print a summary of how many entities were migrated and how many were skipped
