## 1. Dependencies

- [x] 1.1 Add `ex_json_schema` and `sqids` dependencies to `mix.exs` and run `mix deps.get`

## 2. Path Helpers

- [x] 2.1 Create `Goodwizard.Brain.Paths` module with path helpers: `brain_dir/1`, `schemas_dir/1`, `entity_type_dir/2`, `entity_path/3`, `schema_path/2`, `counter_path/1`, and path validation (reject `..`, `/`, null bytes)
- [x] 2.2 Write tests for `Brain.Paths` — path construction, validation, traversal rejection

## 3. ID Generation

- [x] 3.1 Create `Goodwizard.Brain.Id` module — initializes Sqids with lowercase alphanumeric alphabet and min length 8, `generate/1` reads/increments counter file and encodes via Sqids, `valid?/1` validates a string matches the Sqid pattern
- [x] 3.2 Write tests for `Brain.Id` — generates unique IDs, counter increments, counter file creation, ID validation

## 4. Schema Management

- [x] 4.1 Create `Goodwizard.Brain.Schema` module — `load/2` reads and resolves a JSON Schema from disk, `validate/2` validates data against a resolved schema, `save/3` writes a schema file, `list_types/1` scans schemas dir
- [x] 4.2 Write tests for `Brain.Schema` — load, resolve, validate valid data, validate invalid data, save new schema, list types

## 5. Default Schema Seeding

- [x] 5.1 Create `Goodwizard.Brain.Seeds` module that defines the 6 default schemas (people, places, events, notes, tasks, companies) as Elixir maps with `"version": 1` and writes them to disk
- [x] 5.2 Wire schema seeding into brain initialization — seed defaults on first access if schemas dir is empty
- [x] 5.3 Write test for seeding — verify all 6 schema files created with correct structure and version field
