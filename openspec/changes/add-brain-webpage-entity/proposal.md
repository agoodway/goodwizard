## Why

The brain knowledge base stores structured entities but has no way to associate web resources with them. Users need to link relevant URLs — documentation, articles, dashboards, social profiles — to people, companies, events, and other entities. A `webpages` entity type provides first-class URL storage, and adding a `webpages` reference list to base properties lets every other entity type link to multiple web resources.

## What Changes

- Add a `webpages` entity type to the brain with a schema for storing URLs with metadata
- Seed the `webpages` schema alongside the existing 7 default schemas
- Add `webpages` as an `entity_ref_list` in `base_properties` so all other entity types can reference multiple webpages (webpages themselves will NOT have self-references)

## Capabilities

### New Capabilities
- `brain-webpage-entity`: Core `webpages` entity type with schema, seeding, and base-property integration for cross-entity references

### Modified Capabilities

None — existing brain CRUD operations already handle any entity type generically. The base_properties change is part of the new capability since it's intrinsic to how webpages integrate with the entity system.

## Impact

- `Goodwizard.Brain.Seeds` — add `webpages` schema definition, include in `@entity_types`, add `webpages` ref_list to `base_properties` (with exclusion for webpages' own schema)
- `Mix.Tasks.Goodwizard.Setup` — no code change needed (already iterates `Seeds.entity_types()`)
- Existing tests that assert on the exact list of entity types or base property keys will need updating
- All existing entity schemas gain a new optional `webpages` field — purely additive, no breaking changes
