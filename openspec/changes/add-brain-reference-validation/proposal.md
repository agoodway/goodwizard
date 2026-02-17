## Why

Entity references in the brain (e.g. `tasks/019c68dd-6b90-7347-a7db-c19004bbe7ad`, `people/019c7a12-3e45-7891-b234-567890abcdef`) are never validated for existence. When an entity is deleted, any other entities referencing it retain stale IDs. This leads to silent data corruption — the agent presents references that point to nothing, and users have no way to know their data is inconsistent.

## What Changes

- Add a reference validation function that checks whether referenced entities exist on disk
- Clean stale references from entities on read (lazy cleanup) so consumers never see dead references
- Add a `Brain.validate_references/3` function for explicit validation on demand
- After a successful delete, spawn an async task that scans brain files for references to the deleted entity and rewrites any files that contained stale refs
- Handle all three reference shapes: typed single refs (`entity_ref`), typed ref lists (`entity_ref_list`), and polymorphic ref lists (`related_to` on notes)

## Capabilities

### New Capabilities
- `brain-reference-validation`: Validate and clean entity references on read and on demand

### Modified Capabilities

None — existing CRUD return values are preserved. Delete now triggers async cleanup but the caller still gets `:ok` immediately.

## Impact

- `Goodwizard.Brain` — modify `read/3` and `list/2` to filter stale references; modify `delete/3` to trigger async cleanup; add `validate_references/3`
- `Goodwizard.Brain.References` — new module for ref field extraction, cleaning, validation, and async sweep
- Tests — new unit tests for reference validation, cleanup on read, and post-delete sweep
- All 8 entity types affected: people, places, events, notes, tasks, companies, tasklists, webpages
