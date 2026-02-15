## 1. Path Helpers

- [ ] 1.1 Add `schema_history_dir/1`, `schema_migrations_dir/1`, `schema_history_path/3`, `migration_path/4` to `Goodwizard.Brain.Paths`
- [ ] 1.2 Write tests for new path helpers — construction, validation

## 2. Schema Versioning and Archival

- [ ] 2.1 Modify `Goodwizard.Brain.Schema.save/3` to enforce version increment (+1) when updating an existing schema
- [ ] 2.2 Add schema history archival — copy current schema to `brain/schemas/history/<entity_type>_v<N>.json` before overwriting
- [ ] 2.3 Add migration definition storage — write migration to `brain/schemas/migrations/<entity_type>_v<N>_to_v<N+1>.json` on schema update
- [ ] 2.4 Reject schema updates without a migration definition
- [ ] 2.5 Write tests — version increment enforcement, history archival, migration storage, reject update without migration, reject version mismatch

## 3. Migration Module

- [ ] 3.1 Create `Goodwizard.Brain.Migration` module — `load/4` reads a migration definition from disk, `apply_operations/2` applies operations to an entity's frontmatter map, `execute/3` runs migration across all entities of a type with validation and write-back, `dry_run/3` reports changes without writing
- [ ] 3.2 Implement `add_field` operation — adds field with default value
- [ ] 3.3 Implement `rename_field` operation — renames field preserving value
- [ ] 3.4 Implement `remove_field` operation — drops field from frontmatter
- [ ] 3.5 Implement `set_default` operation — sets default only if field absent
- [ ] 3.6 Write tests for each operation, operation ordering, dry-run diff, validation failure skipping, summary counts, missing migration file error

## 4. Agent Action

- [ ] 4.1 Create `Goodwizard.Actions.Brain.MigrateEntities` action — params: entity_type, from_version (integer), to_version (integer), dry_run (boolean, default false)
- [ ] 4.2 Modify `Goodwizard.Actions.Brain.SaveSchema` action — add optional `migration` param (map, required when updating existing schema)
- [ ] 4.3 Add `migrate/4` to `Goodwizard.Brain` public API delegating to Migration module
- [ ] 4.4 Register `MigrateEntities` action in `Goodwizard.Agent` tools list
- [ ] 4.5 Write tests for MigrateEntities action and SaveSchema migration param
