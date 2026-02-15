## Context

The brain knowledge base stores entities as markdown files with YAML frontmatter, validated against JSON Schema definitions. Six entity types ship by default (people, places, events, notes, tasks, companies), defined in `Goodwizard.Brain.Seeds`. The CRUD operations in `Goodwizard.Brain` are generic — they work with any entity type that has a schema. Adding a new type requires only a schema definition and inclusion in the seeds list.

## Goals / Non-Goals

**Goals:**
- Add a `tasklists` entity type that groups `tasks` entities by reference
- Seed the schema automatically alongside existing types
- Maintain the same CRUD patterns used by all other entity types

**Non-Goals:**
- No cascading operations (deleting a tasklist does not delete its tasks)
- No ordering/sorting logic beyond what the schema stores
- No UI or channel-specific behavior

## Decisions

**Schema field design**: The `tasklists` schema will have `title` (required), `description`, `status` (enum: active/completed/archived), and `tasks` as an entity reference list to the `tasks` type. This follows the same `entity_ref_list` pattern used by `companies.contacts` and `events.attendees`.

**Naming: `tasklists` not `task_lists`**: All existing entity types use single lowercase words (people, places, events). `tasklists` follows the same convention as a compound word rather than introducing underscores.

**No schema migration**: Since the brain has no existing `tasklists` data, this is purely additive. `Seeds.seed/1` only writes schemas that don't already exist, so existing workspaces get the new schema on next `ensure_initialized` call.

## Risks / Trade-offs

**Orphaned references** — If a task is deleted, tasklists referencing it will contain stale IDs. This is consistent with how all entity references work in the brain today (no referential integrity enforcement). → Acceptable for now; a future change could add reference validation.
