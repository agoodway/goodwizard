## Why

Brain entities need a standard way to attach arbitrary key-value metadata (e.g. source, import_id, external_url) without modifying schemas per entity type. Currently there is no shared extensibility field — any extra data requires a schema change. A `metadata` map on every entity gives actions and integrations a consistent place to store context without touching type-specific schema definitions.

## What Changes

- Add a **required** `metadata` field to the shared base properties in `Goodwizard.Brain.Seeds`
- The field is a JSON object where both keys and values are strings
- Every entity type schema inherits this field automatically via `base_properties()` and includes `"metadata"` in its `"required"` list
- `metadata` is a **system-protected field**: auto-initialized to `%{}` on create if not provided, and cannot be removed on update
- Add `"metadata"` to `@system_fields` in `Goodwizard.Brain` so the system guarantees its presence
- On create: merge user-provided metadata with the default `%{}`, then set it as a system field
- On update: preserve existing metadata if not provided in update data; never allow removal
- Strip `metadata` from entity data returned by brain actions (`ReadEntity`, `ListEntities`) so it never appears in agent prompts or messages

## Capabilities

### New Capabilities

- `entity-metadata`: A required, system-protected `metadata` key-value string map field present on all brain entity types

### Modified Capabilities

_None_ — this adds a new base property; existing schema behavior is unchanged.

## Impact

- **Code**: `Goodwizard.Brain.Seeds.base_properties/0` (add property + required), `Goodwizard.Brain` (auto-initialize on create, protect on update), `ReadEntity` and `ListEntities` actions (strip metadata from returned data)
- **Schemas**: All 7 seed schemas gain the required field when re-seeded
- **Existing data**: Entities created before this change will fail validation if they lack `metadata`. Users should re-seed schemas and add `metadata: {}` to existing entities.
- **Tests**: Seed/schema tests need updated required field lists; CRUD tests need metadata coverage
