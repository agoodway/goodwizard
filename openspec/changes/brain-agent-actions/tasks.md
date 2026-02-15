## 1. CRUD Actions

- [ ] 1.1 Create `Goodwizard.Actions.Brain.CreateEntity` action — params: entity_type, data (map), body (optional string)
- [ ] 1.2 Create `Goodwizard.Actions.Brain.ReadEntity` action — params: entity_type, id
- [ ] 1.3 Create `Goodwizard.Actions.Brain.UpdateEntity` action — params: entity_type, id, data (map), body (optional string)
- [ ] 1.4 Create `Goodwizard.Actions.Brain.DeleteEntity` action — params: entity_type, id
- [ ] 1.5 Create `Goodwizard.Actions.Brain.ListEntities` action — params: entity_type

## 2. Schema Actions

- [ ] 2.1 Create `Goodwizard.Actions.Brain.GetSchema` action — params: entity_type
- [ ] 2.2 Create `Goodwizard.Actions.Brain.SaveSchema` action — params: entity_type, schema (map)
- [ ] 2.3 Create `Goodwizard.Actions.Brain.ListEntityTypes` action — no required params

## 3. Registration and Testing

- [ ] 3.1 Register all brain actions in `Goodwizard.Agent` tools list
- [ ] 3.2 Write tests for each brain action
