## 1. Schema Updates

- [x] 1.1 Update `priv/workspace/brain/schemas/people.json`: remove `email` and `phone` scalar fields, add `emails`, `phones`, `addresses`, and `socials` as array-of-object properties, bump version to 2
- [x] 1.2 Update `priv/workspace/brain/schemas/companies.json`: remove `location` scalar field, add `emails`, `phones`, `addresses`, and `socials` as array-of-object properties, bump version to 2

## 2. SchemaMapper

- [x] 2.1 Add `map_type/1` clause in `lib/goodwizard/brain/schema_mapper.ex` for `%{"type" => "array", "items" => %{"type" => "object"}}` returning `{:list, :map}`
- [x] 2.2 Add `build_doc/1` clause for array-of-object properties that includes the property description
- [x] 2.3 Add tests for the new `map_type` and `build_doc` clauses

## 3. Entity Serialization Verification

- [x] 3.1 Add tests in entity tests to verify `Entity.serialize/2` and `Entity.parse/1` round-trip arrays of maps (contact objects) correctly
- [x] 3.2 Add tests for nested address objects with multiple sub-fields

## 4. ToolGenerator Verification

- [x] 4.1 Verify generated `CreatePerson` and `UpdatePerson` actions accept list-of-map params for contact fields (add integration test)
- [x] 4.2 Verify generated `CreateCompany` and `UpdateCompany` actions accept list-of-map params for contact fields (add integration test)

## 5. Migration Task

- [x] 5.1 Create `lib/mix/tasks/goodwizard.migrate_contacts.ex` Mix task that scans people and companies entity files
- [x] 5.2 Implement migration logic: convert scalar `email`/`phone` on people to `emails`/`phones` arrays, convert scalar `location` on companies to `addresses` array
- [x] 5.3 Add summary output reporting migrated vs skipped entities
- [x] 5.4 Add tests for the migration task covering all scenarios (migrate, skip, report)

## 6. Existing Test Updates

- [x] 6.1 Update brain schema tests to reflect new field names and types on people and companies
- [x] 6.2 Update any brain action tests that reference old `email`, `phone`, or `location` fields
