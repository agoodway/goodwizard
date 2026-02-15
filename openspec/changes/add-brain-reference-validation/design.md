## Context

Brain entity references use the string pattern `<type>/<id>` (e.g. `tasks/abcd1234`). These appear in two schema forms:
- **Single ref** (`entity_ref`): a string field like `"company"` on people
- **Ref list** (`entity_ref_list`): an array field like `"contacts"` on companies, `"attendees"` on events

References are validated by JSON Schema regex at write time, but existence of the target entity is never checked. When a referenced entity is deleted, the reference becomes stale.

The reference pattern is embedded in the schema's `properties` — each ref field has a `"pattern"` containing the target type name (e.g. `^tasks/[a-z0-9]{8,}$`). Array ref fields nest this under `"items"."pattern"`.

## Goals / Non-Goals

**Goals:**
- Clean stale references transparently on read so consumers never see dead IDs
- Provide a `validate_references/3` function for explicit checking
- Extract reference field detection from schema properties

**Non-Goals:**
- No cascading deletes — deleting an entity does not delete referencing entities
- No write-time validation (checking refs exist before saving) — this would add latency and complexity to every create/update

## Decisions

**Two-layer cleanup — lazy on read, async sweep on delete**: Read-time filtering gives consumers clean data immediately. Post-delete async sweep actually rewrites files on disk to remove stale refs, so the data converges to a clean state over time. Delete stays fast because the sweep runs in a spawned `Task` — the caller gets `:ok` immediately.

**Schema introspection for ref field discovery**: Rather than hardcoding which fields are references, extract them from the schema's `properties`. A field is a single ref if it has `"type" => "string"` and a `"pattern"` matching `^<type>/`. A field is a ref list if it has `"type" => "array"` with `"items"."pattern"` matching the same. This makes the system automatically handle any new entity type with references.

**Filter-not-rewrite on read**: `read/3` and `list/2` will filter stale refs from the returned data maps in memory. They will NOT rewrite the file on disk — that would turn reads into writes, introduce locking concerns, and create surprising side effects. The stale refs remain on disk until the entity is explicitly updated.

**New module `Brain.References`**: Keep reference logic in a dedicated module rather than growing `Brain` further. Functions: `clean_data/3` (removes stale refs from a data map), `validate/3` (returns list of stale refs without cleaning), `ref_fields/1` (extracts ref field info from a schema), `sweep_stale/3` (scans all entity types for refs to a deleted entity and rewrites affected files).

**Async sweep via `Task.start/1`**: After `Brain.delete/3` succeeds, it spawns `Task.start(fn -> References.sweep_stale(workspace, entity_type, id) end)`. The sweep loads all schemas to find which types have ref fields pointing at the deleted type, reads each entity of those types, removes the stale ref, and rewrites the file using the existing `Brain.update` locked-write path. Failures are logged but do not propagate — the delete already succeeded.

## Risks / Trade-offs

**Read performance** — Each read now checks file existence for every reference. For entities with many refs this adds syscalls. → Acceptable because brain entities typically have few references (< 10), and `File.exists?` is fast for local filesystem.

**Async sweep failures** — If the sweep crashes or partially completes, some files retain stale refs on disk. → Acceptable because read-time filtering still prevents consumers from seeing them. The sweep is best-effort convergence, not a guarantee.
