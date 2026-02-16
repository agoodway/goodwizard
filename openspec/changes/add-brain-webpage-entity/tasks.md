## 1. Schema Definition

- [x] 1.1 Add `schema_for("webpages")` function to `Goodwizard.Brain.Seeds` with fields: `title` (required), `url` (required, format: uri), `description` (optional). Remove the `webpages` self-reference from the built schema's properties.
- [x] 1.2 Add `"webpages"` to the `@entity_types` list in `Goodwizard.Brain.Seeds`
- [x] 1.3 Add `"webpages" => entity_ref_list("webpages")` to `base_properties/0` in `Goodwizard.Brain.Seeds`

## 2. Tests

- [x] 2.1 Add seed test for `webpages` schema in `test/goodwizard/brain/seeds_test.exs` — verify required fields, url format, description optional
- [x] 2.2 Add CRUD integration test for webpages entity in `test/goodwizard/brain_crud_test.exs` — create, read, list
- [x] 2.3 Add test verifying other entity types include `webpages` ref_list property in their schemas
- [x] 2.4 Add test verifying the `webpages` schema does NOT include a `webpages` self-reference property
- [x] 2.5 Update setup task test assertions in `test/mix/tasks/goodwizard_setup_test.exs` to include `webpages`
