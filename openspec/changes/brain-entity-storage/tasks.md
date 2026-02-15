## 1. Entity File Format

- [x] 1.1 Create `Goodwizard.Brain.Entity` module — `parse/1` reads markdown with YAML frontmatter into `{data_map, body_string}`, `serialize/2` converts data map + body into frontmatter markdown string
- [x] 1.2 Write tests for `Brain.Entity` — parse roundtrip, missing frontmatter, empty body, special YAML characters

## 2. Brain Public API

- [x] 2.1 Create `Goodwizard.Brain` public API module — `create/4`, `read/3`, `update/4`, `delete/3`, `list/2` delegating to Schema, Entity, Id, and Paths modules
- [x] 2.2 Wire brain initialization into create/list — ensure directory structure and default schemas exist on first use
- [x] 2.3 Write tests for `Brain` CRUD — create entity, read back, update fields, delete, list, duplicate ID error, not-found error, schema validation error
