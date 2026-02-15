## Context

The brain knowledge base ships with 6 seeded entity types defined in `Brain.Seeds` (`people`, `places`, `events`, `notes`, `tasks`, `companies`). These types and their schemas are created on first initialization and form the brain's foundational structure. Currently, `Brain.delete/3` has no awareness of whether an entity type is seeded — any delete request is forwarded directly to `File.rm/1`.

## Goals / Non-Goals

**Goals:**
- Prevent deletion of seeded entity type schemas so the brain's foundational structure cannot be accidentally destroyed
- Keep the seeded-type list centralized in `Brain.Seeds.entity_types/0` — single source of truth, no duplication

**Non-Goals:**
- Protecting individual entities within seeded types (users/agents should freely create and delete entities of any type)
- Preventing deletion of user-created custom entity types
- Schema immutability (schemas can still be updated via `save_schema`, just not deleted)

## Decisions

**1. Guard at the action layer, not the core layer**

The `DeleteEntity` action will check whether the caller is attempting to delete a seeded entity type's schema before calling `Brain.delete/3`. The core `Brain.delete/3` function remains a low-level file operation — it doesn't need to know about seeded types.

*Rationale*: Keeps `Brain` as a clean storage layer. Policy decisions belong in the action layer where they're visible to callers and easy to test independently. If a future internal process legitimately needs to replace a seeded schema, it can call `Brain` directly without fighting the guard.

*Alternative considered*: Putting the guard in `Brain.delete/3`. Rejected because it mixes policy with storage and makes the core module aware of seed concepts.

**2. Clarify scope: this protects schemas, not entities**

The delete entity action deletes individual entity files (`brain/<type>/<id>.md`). The concern from the proposal is about protecting the *type itself* — meaning the schema file. Individual entity instances within seeded types can still be deleted freely.

Since `DeleteEntity` only deletes entity instances (not schemas), the actual protection needs to be in the schema deletion path. If no `delete_schema` action exists yet, we need to ensure the schema deletion path (if/when it exists) checks for seeded types.

*Decision*: Add a `Brain.Seeds.seeded_type?/1` helper. Use it wherever schema deletion could occur. For now, that means guarding the `Schema.delete` path (or adding one if it doesn't exist).

**3. Use `Brain.Seeds.entity_types/0` as the canonical list**

Add a `Brain.Seeds.seeded_type?/1` convenience function that checks membership against `entity_types/0`. This keeps the seeded-type list in one place and provides a clean API for guards.

## Risks / Trade-offs

- **[Risk] Future entity types added to seeds but protection not updated** → Mitigated because `seeded_type?/1` delegates to `entity_types/0`, so adding a type to the `@entity_types` list automatically protects it.
- **[Trade-off] Action-layer guard vs core-layer guard** → If someone bypasses the action layer and calls schema deletion directly, the guard won't fire. Acceptable because direct `Brain` module callers are internal code, not AI agents.
