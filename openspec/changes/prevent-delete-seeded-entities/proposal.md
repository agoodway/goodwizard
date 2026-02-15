## Why

The brain's delete action (`Brain.DeleteEntity`) has no guardrails — it can delete any entity, including the core seeded entity types (`people`, `places`, `events`, `notes`, `tasks`, `companies`) and their schemas. If an AI agent or user accidentally deletes a seeded schema or entity type directory, the brain loses its foundational structure and requires a full re-seed to recover.

## What Changes

- Add a "seeded entity type" guard to `Brain.delete/3` that rejects deletion of schema files for core seeded types
- The guard checks against the canonical list from `Brain.Seeds.entity_types/0`
- Deleting **individual entities** within seeded types (e.g. a specific person) remains allowed — only the type-level schemas are protected
- Return a clear `{:error, :protected_entity_type}` when deletion of a protected schema is attempted

## Capabilities

### New Capabilities

- `seeded-type-protection`: Guard logic that prevents deletion of core seeded entity type schemas, using `Brain.Seeds.entity_types/0` as the source of truth

### Modified Capabilities

_(none — no existing specs to modify)_

## Impact

- `lib/goodwizard/brain.ex` — `delete/3` gains a pre-check
- `lib/goodwizard/actions/brain/delete_entity.ex` — surfaces the new error to callers
- Tests — new test cases for protected deletion attempts and confirmation that normal entity deletion still works
