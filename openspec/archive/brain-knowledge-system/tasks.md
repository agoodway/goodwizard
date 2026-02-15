## 1. Dependencies and Foundation

- [ ] 1.1 Add `ex_json_schema` and `sqids` dependencies to `mix.exs` and run `mix deps.get`
- [ ] 1.2 Create `Goodwizard.Brain.Paths` module with path helpers: `brain_dir/1`, `schemas_dir/1`, `entity_type_dir/2`, `entity_path/3`, `schema_path/2`, `counter_path/1`, and path validation (reject `..`, `/`, null bytes)
- [ ] 1.3 Create `Goodwizard.Brain.Id` module — initializes Sqids with lowercase alphanumeric alphabet and min length 8, `generate/1` reads/increments counter file and encodes via Sqids, `valid?/1` validates a string matches the Sqid pattern
- [ ] 1.4 Write tests for `Brain.Paths` — path construction, validation, traversal rejection
- [ ] 1.5 Write tests for `Brain.Id` — generates unique IDs, counter increments, counter file creation, ID validation

## 2. Schema Management

- [ ] 2.1 Create `Goodwizard.Brain.Schema` module — `load/2` reads and resolves a JSON Schema from disk, `validate/2` validates data against a resolved schema, `save/3` writes a schema file, `list_types/1` scans schemas dir
- [ ] 2.2 Create the 6 initial JSON Schema files as embedded resources: people, places, events, notes, tasks, companies (each with common fields + type-specific fields per spec)
- [ ] 2.3 Write `Brain.Schema` setup function that copies default schemas to `brain/schemas/` if they don't exist (called on first use)
- [ ] 2.4 Write tests for `Brain.Schema` — load, resolve, validate valid data, validate invalid data, save new schema, list types

## 3. Entity Storage

- [ ] 3.1 Create `Goodwizard.Brain.Entity` module — `parse/1` reads markdown with YAML frontmatter into `{data_map, body_string}`, `serialize/2` converts data map + body into frontmatter markdown string
- [ ] 3.2 Write tests for `Brain.Entity` — parse roundtrip, missing frontmatter, empty body, special YAML characters
- [ ] 3.3 Create `Goodwizard.Brain` public API module — `create/4`, `read/3`, `update/4`, `delete/3`, `list/2` delegating to Schema and Entity modules
- [ ] 3.4 Write tests for `Brain` CRUD — create entity, read back, update fields, delete, list, duplicate ID error, not-found error, schema validation error

## 4. Agent Actions

- [ ] 4.1 Create `Goodwizard.Actions.Brain.CreateEntity` action — params: entity_type, data (map), body (optional string)
- [ ] 4.2 Create `Goodwizard.Actions.Brain.ReadEntity` action — params: entity_type, id
- [ ] 4.3 Create `Goodwizard.Actions.Brain.UpdateEntity` action — params: entity_type, id, data (map), body (optional string)
- [ ] 4.4 Create `Goodwizard.Actions.Brain.DeleteEntity` action — params: entity_type, id
- [ ] 4.5 Create `Goodwizard.Actions.Brain.ListEntities` action — params: entity_type
- [ ] 4.6 Create `Goodwizard.Actions.Brain.GetSchema` action — params: entity_type
- [ ] 4.7 Create `Goodwizard.Actions.Brain.SaveSchema` action — params: entity_type, schema (map)
- [ ] 4.8 Create `Goodwizard.Actions.Brain.ListEntityTypes` action — no required params
- [ ] 4.9 Write tests for each brain action
- [ ] 4.10 Register all brain actions in `Goodwizard.Agent` tools list

## 5. Default Schemas Seeding

- [ ] 6.1 Create a `Goodwizard.Brain.Seeds` module that generates the 6 default schemas (with `"version": 1`) as Elixir maps and writes them to disk
- [ ] 6.2 Wire schema seeding into brain initialization — seed defaults on first access if schemas dir is empty
- [ ] 6.3 Write test for seeding — verify all 6 schema files created with correct structure and version field
