## Why

The brain knowledge base has a `tasks` entity type for individual tasks, but no way to group tasks into a list. Users need to organize related tasks together — project checklists, shopping lists, daily plans. A `tasklists` entity type provides this grouping with references to child tasks.

## What Changes

- Add a `tasklists` entity type to the brain with a schema that references `tasks` entities
- Seed the `tasklists` schema alongside the existing 6 default schemas
- Update `mix goodwizard.setup` to create the `brain/tasklists/` directory

## Capabilities

### New Capabilities
- `brain-tasklist-entity`: Core `tasklists` entity type with schema, seeding, and setup integration

### Modified Capabilities

None — existing brain CRUD operations already handle any entity type generically.

## Impact

- `Goodwizard.Brain.Seeds` — add `tasklists` schema definition and include in `@entity_types`
- `Mix.Tasks.Goodwizard.Setup` — no code change needed (already iterates `Seeds.entity_types()`)
- Existing tests that assert on the exact list of entity types will need updating
