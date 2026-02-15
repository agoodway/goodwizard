## Context

This change builds on `brain-foundation`, which provides `Brain.Paths`, `Brain.Id`, `Brain.Schema`, and `Brain.Seeds`. Those modules handle path safety, ID generation, schema loading/validation, and default schema seeding.

This change adds the entity file format and a public CRUD API that ties everything together.

## Goals / Non-Goals

**Goals:**
- Parse markdown files with YAML frontmatter into `{data_map, body_string}` tuples
- Serialize data maps + body strings back into frontmatter markdown
- Provide a clean public API (`Goodwizard.Brain`) for CRUD operations with schema validation
- Handle error cases: not found, duplicate ID, schema validation failure

**Non-Goals:**
- Agent-facing Jido actions (see `brain-agent-actions`)
- Search or indexing
- Relationship traversal

## Decisions

### 1. File format: Markdown with YAML frontmatter

Entity files use standard markdown with YAML frontmatter for structured fields:

```markdown
---
id: "k3g7qae5"
name: John Doe
email: john@example.com
company: "companies/x9rku2dq"
tags: [friend, colleague]
created_at: "2026-02-14T00:00:00Z"
updated_at: "2026-02-14T00:00:00Z"
---

Free-form notes about John go here.
Met at the conference in Austin.
```

**Rationale**: Markdown + YAML frontmatter is human-readable, git-friendly, and widely supported. The `yaml_elixir` dependency already exists in the project. Structured fields live in frontmatter (validated by JSON Schema), while the body holds freeform notes.

### 2. Entity module

`Goodwizard.Brain.Entity` provides two functions:

- `parse/1` — takes a file content string, splits on `---` delimiters, parses YAML frontmatter into a map, returns `{:ok, {data_map, body_string}}`
- `serialize/2` — takes a data map and body string, serializes the map as YAML frontmatter and appends the body, returns the file content string

### 3. Brain public API

`Goodwizard.Brain` is the main entry point:

- `create(workspace, entity_type, data, body \\ "")` — generates ID, sets timestamps, validates against schema, writes file
- `read(workspace, entity_type, id)` — reads and parses entity file
- `update(workspace, entity_type, id, data, body \\ nil)` — reads existing, merges data, updates `updated_at`, validates, writes
- `delete(workspace, entity_type, id)` — deletes entity file
- `list(workspace, entity_type)` — lists all entity files in a type directory, returns parsed entities

On first use, `create` and `list` ensure the brain directory structure and default schemas exist (delegates to `Brain.Seeds`).

### 4. Entity references use `entity-type/sqid` format

Fields that reference another entity use the string format `<entity_type>/<sqid>` — e.g., `"companies/x9rku2dq"`. Validated by JSON Schema pattern constraints defined in `brain-foundation`.

**Rationale**: Self-describing references that mirror the filesystem path. No referential integrity enforcement — that's a future enhancement.

## Risks / Trade-offs

- **[No search/indexing]** — Listing entities requires directory scan. Acceptable for hundreds of entities; would need indexing for thousands.
- **[No referential integrity]** — Entity references are not validated to exist. A future "validate refs" command could check this.
- **[YAML parsing edge cases]** — Some YAML values get auto-coerced. Mitigated by quoting strings in frontmatter.
