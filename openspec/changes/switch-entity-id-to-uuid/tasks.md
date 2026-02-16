## 1. Rewrite ID Module

- [ ] 1.1 Rewrite `lib/goodwizard/brain/id.ex`: replace all Sqids/counter logic with UUIDv7 generation via `Uniq.UUID.uuid7/0`. `generate/1` calls `Uniq.UUID.uuid7()` (no filesystem access). Update `@id_pattern_string` to `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`. Update `valid?/1` to match the new pattern. Remove all counter, locking, and recovery functions.

## 2. Update Schema Patterns

- [ ] 2.1 Update `base_properties/0` in `lib/goodwizard/brain/seeds.ex`: change the `id` property pattern to use `Id.id_pattern()` (already does, but verify it picks up the new pattern)
- [ ] 2.2 Update `entity_ref/1` in `lib/goodwizard/brain/seeds.ex`: change pattern from `^#{type}/[a-z0-9]{8,64}$` to `^#{type}/` followed by the UUID pattern
- [ ] 2.3 Update `entity_ref_list/1` in `lib/goodwizard/brain/seeds.ex`: same UUID pattern update for list item patterns
- [ ] 2.4 Update the polymorphic reference pattern in `schema_for("notes")`: change from `^[a-z_]+/[a-z0-9]{8,64}$` to `^[a-z_]+/` followed by the UUID pattern

## 3. Replace sqids Dependency with uniq

- [ ] 3.1 Remove `:sqids` and add `:uniq` in deps in `mix.exs`
- [ ] 3.2 Run `mix deps.unlock sqids && mix deps.clean sqids && mix deps.get` to clean up and fetch new dependency

## 4. Clean Up Dead Code

- [ ] 4.1 Remove `counter_path/1` from `lib/goodwizard/brain/paths.ex` if no other code references it

## 5. Tests

- [ ] 5.1 Update ID generation tests: verify `Id.generate/1` returns a valid UUIDv7 (version nibble is `7`), verify uniqueness across multiple calls, verify time-ordering (ID generated later sorts after earlier), verify `Id.valid?/1` accepts UUIDs and rejects sqids-format strings
- [ ] 5.2 Update seed schema tests: verify all 7 schemas use UUID patterns for `id`, entity refs, and polymorphic refs
- [ ] 5.3 Update brain CRUD tests: verify entity create/read/update/delete round-trips work with UUIDv7 IDs
- [ ] 5.4 Verify no test references the `Sqids` module or old ID patterns
