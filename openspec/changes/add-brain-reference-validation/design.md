## Context

Brain entity references use UUIDv7-based string patterns in the form `<type>/<uuid>` (e.g. `companies/019c68dd-6b90-7347-a7db-c19004bbe7ad`). The UUID pattern is `[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}`. These appear in three schema forms:

- **Single ref** (`entity_ref`): a string field like `"company"` on people, with `"pattern" => "^companies/<uuid>$"` and `"description" => "Entity reference to companies"`
- **Ref list** (`entity_ref_list`): an array field like `"contacts"` on companies, `"attendees"` on events, with `"items"."pattern" => "^people/<uuid>$"` and `"description" => "Entity references to people"`
- **Polymorphic ref list**: the `"related_to"` field on notes, with `"items"."pattern" => "^[a-z_]+/<uuid>$"` — can reference any entity type

The 8 entity types (people, places, events, notes, tasks, companies, tasklists, webpages) form a reference graph:

| Entity Type | Field | Shape | Target Type |
|---|---|---|---|
| all types (base) | `notes` | ref list | notes |
| all types (base) | `webpages` | ref list | webpages |
| people | `company` | single ref | companies |
| events | `location` | single ref | places |
| events | `attendees` | ref list | people |
| tasks | `assignee` | single ref | people |
| companies | `contacts` | ref list | people |
| tasklists | `tasks` | ref list | tasks |
| notes | `related_to` | polymorphic ref list | any type |

References are validated by JSON Schema regex at write time, but existence of the target entity is never checked. When a referenced entity is deleted, the reference becomes stale.

All entities have a required `metadata` field (arbitrary key-value string map) that is persisted but hidden from LLM tool results. This field is not involved in reference validation.

## Goals / Non-Goals

**Goals:**
- Clean stale references transparently on read so consumers never see dead IDs
- Provide a `validate_references/3` function for explicit checking
- Extract reference field detection from schema properties, handling all three ref shapes
- Handle the polymorphic `related_to` pattern where the target type is extracted from the reference value itself

**Non-Goals:**
- No cascading deletes — deleting an entity does not delete referencing entities
- No write-time validation (checking refs exist before saving) — this would add latency and complexity to every create/update
- No metadata-based backlink tracking — keep the implementation simple with file-existence checks

## Decisions

**Two-layer cleanup — lazy on read, async sweep on delete**: Read-time filtering gives consumers clean data immediately. Post-delete async sweep actually rewrites files on disk to remove stale refs, so the data converges to a clean state over time. Delete stays fast because the sweep runs in a spawned `Task` — the caller gets `:ok` immediately.

**Schema introspection for ref field discovery**: Rather than hardcoding which fields are references, extract them from the schema's `properties`. Detection rules:

1. **Single typed ref**: `"type" => "string"` with a `"pattern"` containing `/<uuid-pattern>$` where the prefix before `/` is the target type
2. **Typed ref list**: `"type" => "array"` with `"items"."pattern"` containing `/<uuid-pattern>$` where the prefix is the target type
3. **Polymorphic ref list**: `"type" => "array"` with `"items"."pattern"` matching `^[a-z_]+/` — target type is extracted from each reference value at runtime, not from the schema

This makes the system automatically handle any new entity type with references, including custom schemas saved via `SaveSchema`.

**Filter-not-rewrite on read**: `read/3` and `list/2` will filter stale refs from the returned data maps in memory. They will NOT rewrite the file on disk — that would turn reads into writes, introduce locking concerns, and create surprising side effects. The stale refs remain on disk until the entity is explicitly updated or the async sweep runs.

**New module `Brain.References`**: Keep reference logic in a dedicated module rather than growing `Brain` further. Functions: `clean_data/3` (removes stale refs from a data map), `validate/3` (returns list of stale refs without cleaning), `ref_fields/1` (extracts ref field info from a schema), `sweep_stale/3` (scans all entity types for refs to a deleted entity and rewrites affected files).

**Async sweep via `Task.start/1`**: After `Brain.delete/3` succeeds, it spawns `Task.start(fn -> References.sweep_stale(workspace, entity_type, id) end)`. The sweep loads all schemas to find which types have ref fields pointing at the deleted type (or polymorphic fields that could reference any type), reads each entity of those types, removes the stale ref, and rewrites the file using the existing `Brain.update` locked-write path. Failures are logged but do not propagate — the delete already succeeded.

**Polymorphic sweep inclusion**: When sweeping after a delete, polymorphic ref fields (like `related_to` on notes) must always be included in the scan regardless of the deleted entity's type, since they can reference any type.

## Risks / Trade-offs

**Read performance** — Each read now checks file existence for every reference. For entities with many refs this adds syscalls. → Acceptable because brain entities typically have few references (< 10), and `File.exists?` is fast for local filesystem.

**Polymorphic ref resolution** — Polymorphic refs require parsing the reference value to determine the target type and ID, then checking existence. This is slightly more expensive than typed refs where the target type is known from the schema. → Acceptable because only notes use polymorphic refs currently, and `related_to` lists are typically small.

**Async sweep failures** — If the sweep crashes or partially completes, some files retain stale refs on disk. → Acceptable because read-time filtering still prevents consumers from seeing them. The sweep is best-effort convergence, not a guarantee.
