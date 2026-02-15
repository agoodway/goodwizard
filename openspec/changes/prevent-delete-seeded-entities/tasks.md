## 1. Seeded Type Helper

- [ ] 1.1 Add `seeded_type?/1` function to `Brain.Seeds` that checks membership against `entity_types/0`

## 2. Delete Guard

- [ ] 2.1 Add `:protected_entity_type` guard to `DeleteEntity` action — before calling `Brain.delete/3`, check if the entity type is seeded and the operation would remove the type schema; return `{:error, :protected_entity_type}` if so
- [ ] 2.2 Format `:protected_entity_type` error in `DeleteEntity` as `"Cannot delete protected entity type: <type>"`

## 3. Tests

- [ ] 3.1 Add unit tests for `Brain.Seeds.seeded_type?/1` — true for all 6 seeded types, false for custom types
- [ ] 3.2 Add action tests for `DeleteEntity` — rejection of seeded type schema deletion, success for normal entity deletion within seeded types, success for custom type deletion
