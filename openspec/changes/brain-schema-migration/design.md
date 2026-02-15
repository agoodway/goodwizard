## Context

The brain knowledge system (`brain-knowledge-system` change) provides file-based entity storage with JSON Schema validation. Schemas can be created and updated via the `SaveSchema` action, but there is no mechanism to migrate existing entity data when a schema changes. This change adds schema versioning and migration support.

**Dependency**: Requires `brain-knowledge-system` to be implemented first.

## Goals / Non-Goals

**Goals:**
- Schema versioning with an integer `version` field on each schema
- Previous schema archival to `brain/schemas/history/` on update
- Migration definitions stored in `brain/schemas/migrations/` describing data transforms
- `MigrateEntities` action to apply migrations to all entities of a type
- Dry-run mode to preview changes before applying
- Enforce migration definition requirement when updating an existing schema

**Non-Goals:**
- Complex migration transforms (type coercion, computed fields, conditional logic)
- Multi-version chain migrations (e.g., v1 → v3 in one step) — must migrate one version at a time
- Automatic migration on schema save — migration is a separate explicit step
- Rollback/undo support — archived schemas provide context but no automated rollback

## Decisions

### 1. Schema versioning

Each schema carries a top-level `version` integer, starting at `1`. When a schema is updated via `SaveSchema`, the new version must be exactly `current + 1`. The version field is outside the JSON Schema spec (a custom extension) and is stripped before schema resolution.

**Rationale**: Simple monotonic versioning is easy to reason about. Enforcing +1 increments prevents gaps and makes migration chains predictable.

### 2. Schema history archival

When a schema is updated, the current version is archived to `brain/schemas/history/<entity_type>_v<N>.json` before overwriting. The `history/` directory is auto-created on first use.

```
brain/
  schemas/
    people.json              ← current (v2)
    history/
      people_v1.json         ← archived v1
    migrations/
      people_v1_to_v2.json   ← migration definition
```

**Rationale**: Archiving provides rollback context and audit trail. Stored alongside the active schemas in a predictable location.

### 3. Migration definition format

When updating a schema, a migration definition is provided alongside the new schema. The migration describes structural transforms to apply to existing entities:

```json
{
  "from_version": 1,
  "to_version": 2,
  "operations": [
    { "op": "add_field", "field": "website", "default": null },
    { "op": "rename_field", "from": "notes_ref", "to": "notes" },
    { "op": "remove_field", "field": "deprecated_field" },
    { "op": "set_default", "field": "status", "value": "pending" }
  ]
}
```

Supported operations:
- `add_field` — add a new field with a default value (or `null`)
- `rename_field` — rename a field, preserving its value
- `remove_field` — drop a field from frontmatter
- `set_default` — set a default value for an existing field only if it is currently absent

Operations are applied in order. The migration file is stored at `brain/schemas/migrations/<entity_type>_v<from>_to_v<to>.json`.

**Rationale**: The four operations cover the common structural changes without complex transforms. Order-dependent application lets operations compose (e.g., rename then set_default on the renamed field).

### 4. Migration execution

The `MigrateEntities` action:
1. Reads the migration definition from `brain/schemas/migrations/<entity_type>_v<from>_to_v<to>.json`
2. Scans all entities of that type
3. Applies each operation in order to each entity's frontmatter
4. Validates the result against the new schema
5. Writes the updated entity back to disk (updating `updated_at`)
6. Returns a summary: migrated count, skipped count, errors

Entities that fail validation after migration are skipped (not written) and included in the error list. Migration continues for remaining entities.

**Rationale**: Per-entity error handling prevents one bad entity from blocking the entire migration. The summary gives the agent clear feedback on what happened.

### 5. Dry-run mode

The `MigrateEntities` action accepts a `dry_run: true` parameter. In dry-run mode, it performs all the same steps (read, apply, validate) but does not write any files. It returns the same summary plus a diff of changes per entity.

**Rationale**: Dry-run prevents surprises and lets the agent (or user) preview the impact before committing.

### 6. Module structure

```
Goodwizard.Brain.Migration  — Migration loading, operation application, execution, dry-run
```

New Jido action:
```
Goodwizard.Actions.Brain.MigrateEntities
```

Modified modules:
```
Goodwizard.Brain.Schema  — save/3 gains version validation, history archival, migration storage
Goodwizard.Brain.Paths   — add schema_history_dir/1, schema_migrations_dir/1, schema_history_path/3, migration_path/4
```

### 7. SaveSchema changes

When `SaveSchema` is called for an entity type that already has a schema:
1. Validate the new schema's `version` is exactly `current + 1`
2. Archive the current schema to `brain/schemas/history/<entity_type>_v<N>.json`
3. Store the migration definition to `brain/schemas/migrations/<entity_type>_v<N>_to_v<N+1>.json`
4. Overwrite the current schema file

If no migration definition is provided for an update, the action returns an error. New schemas (no existing schema) do not require a migration.

## Risks / Trade-offs

- **[No chain migrations]** → Migrating from v1 to v3 requires running v1→v2 then v2→v3 sequentially. Mitigation: acceptable for a file-based system; chain support can be added later.
- **[No rollback]** → There is no automated rollback. Mitigation: archived schemas provide context; git history provides full rollback capability.
- **[Partial migration]** → If migration is interrupted, some entities may be migrated and others not. Mitigation: dry-run first; re-running migration on already-migrated entities that pass validation will skip them.
- **[Simple operations only]** → Type coercion, computed fields, and conditional logic are not supported. Mitigation: the agent can handle complex transforms by manually updating entities before or after migration.
