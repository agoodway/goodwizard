## 1. Schema Definition

- [x] 1.1 Add `schema_for("tasklists")` function to `Goodwizard.Brain.Seeds` with fields: `title` (required), `description`, `status` (enum: active/completed/archived), `tasks` (entity_ref_list to tasks)
- [x] 1.2 Add `"tasklists"` to the `@entity_types` list in `Goodwizard.Brain.Seeds`

## 2. Tests

- [x] 2.1 Add seed test for `tasklists` schema in `test/goodwizard/brain/seeds_test.exs`
- [x] 2.2 Add CRUD integration test for tasklists entity in `test/goodwizard/brain_crud_test.exs`
- [x] 2.3 Update setup task test assertions in `test/mix/tasks/goodwizard_setup_test.exs` to include `tasklists`
