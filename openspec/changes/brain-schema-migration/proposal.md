## Why

The brain knowledge system supports creating and updating JSON Schemas for entity types, but updating a schema leaves existing entities invalid against the new schema. Without a migration mechanism, schema updates are effectively destructive — the agent can't safely evolve entity types over time. A versioned migration system lets schemas evolve while keeping existing data consistent.

## What Changes

- Add schema versioning with a `version` integer on each schema
- Archive previous schema versions to `brain/schemas/history/` on update
- Store migration definitions in `brain/schemas/migrations/` describing how to transform entity data between versions
- Build a `Goodwizard.Brain.Migration` module for applying migrations to entities
- Add a `MigrateEntities` Jido action with dry-run support
- Require a migration definition when updating an existing schema via `SaveSchema`

## Capabilities

### New Capabilities
- `brain-migration`: Schema versioning, migration definitions, history archival, and entity migration execution with dry-run support

### Modified Capabilities
- `brain-schemas`: `SaveSchema` action now requires a migration definition when updating an existing schema, enforces version increment, and archives the previous schema version

## Impact

- **Filesystem**: Creates `brain/schemas/history/` and `brain/schemas/migrations/` subdirectories
- **Agent tools**: New `MigrateEntities` action registered in agent tool list; `SaveSchema` action gains `migration` parameter
- **Existing code**: Modifies `Brain.Schema.save/3` to handle versioning and archival; modifies `Brain.Paths` to add history/migration path helpers
