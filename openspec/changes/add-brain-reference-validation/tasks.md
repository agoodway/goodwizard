## 1. Reference Field Extraction

- [ ] 1.1 Create `lib/goodwizard/brain/references.ex` with `ref_fields/1` that extracts single ref and ref list fields from a resolved schema's properties
- [ ] 1.2 Add tests for `ref_fields/1` covering single refs, ref lists, and non-reference fields

## 2. Stale Reference Cleaning

- [ ] 2.1 Add `clean_data/3` to `Brain.References` that takes workspace, schema, and entity data — returns data with stale single refs set to nil and stale list refs filtered out
- [ ] 2.2 Integrate `clean_data/3` into `Brain.read/3` to clean returned data
- [ ] 2.3 Integrate `clean_data/3` into `Brain.list/2` to clean each returned entity
- [ ] 2.4 Add tests for stale reference cleaning on read (single ref, ref list, mixed valid/stale, all valid, file unchanged)

## 3. Explicit Validation

- [ ] 3.1 Add `validate/3` to `Brain.References` that returns `[{field_name, stale_ref}]` tuples without modifying data
- [ ] 3.2 Add tests for `validate/3` covering stale and valid reference scenarios

## 4. Async Post-Delete Sweep

- [ ] 4.1 Add `sweep_stale/3` to `Brain.References` that takes workspace, entity_type, and id — loads all schemas, finds types with ref fields pointing at the deleted type, reads their entities, and rewrites files with stale refs removed
- [ ] 4.2 Modify `Brain.delete/3` to spawn `Task.start(fn -> References.sweep_stale(...) end)` after successful deletion
- [ ] 4.3 Add tests for sweep — verify stale refs are removed from disk after delete, verify only relevant types are scanned, verify sweep failure is logged without affecting delete result
