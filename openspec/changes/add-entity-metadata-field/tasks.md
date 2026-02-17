## 1. Schema Definition

- [x] 1.1 Add `metadata` property to `base_properties/0` in `lib/goodwizard/brain/seeds.ex` as `%{"type" => "object", "additionalProperties" => %{"type" => "string"}, "description" => "Arbitrary key-value string metadata"}`
- [x] 1.2 Update `build_schema/3` in `lib/goodwizard/brain/seeds.ex` to always append `"metadata"` to the `required` list

## 2. Brain CRUD — System Protection

- [x] 2.1 In `Goodwizard.Brain.do_create/4`, add `Map.put_new(data, "metadata", %{})` after the system field merge so metadata defaults to `%{}` when not provided
- [x] 2.2 In `Goodwizard.Brain.locked_update/5`, drop `"metadata"` from `safe_data` when its value is `nil` to prevent removal

## 3. Action Results — Strip Metadata

- [x] 3.1 In `ReadEntity.run/2`, strip `metadata` from the data map before returning (`Map.drop(data, ["metadata"])`)
- [x] 3.2 In `ListEntities.run/2`, strip `metadata` from each entity's data map before returning

## 4. Tests

- [x] 4.1 Add test in `test/goodwizard/brain/seeds_test.exs` verifying all 7 seed schemas include `metadata` in both `properties` and `required`
- [x] 4.2 Add test in `test/goodwizard/brain_crud_test.exs` for creating an entity with a `metadata` map and reading it back
- [x] 4.3 Add test in `test/goodwizard/brain_crud_test.exs` for creating an entity without `metadata` — verify it defaults to `%{}`
- [x] 4.4 Add test in `test/goodwizard/brain_crud_test.exs` for schema rejection when `metadata` contains a non-string value
- [x] 4.5 Add test in `test/goodwizard/brain_crud_test.exs` for update with `metadata: nil` — verify existing metadata is preserved
- [x] 4.6 Add test for `ReadEntity` action verifying `metadata` is not present in the returned data
- [x] 4.7 Add test for `ListEntities` action verifying `metadata` is not present in any returned entity data
