## 1. CRUD Actions

- [x] 1.1 Create `Goodwizard.Actions.Brain.CreateEntity` action — params: entity_type, data (map), body (optional string)
- [x] 1.2 Create `Goodwizard.Actions.Brain.ReadEntity` action — params: entity_type, id
- [x] 1.3 Create `Goodwizard.Actions.Brain.UpdateEntity` action — params: entity_type, id, data (map), body (optional string)
- [x] 1.4 Create `Goodwizard.Actions.Brain.DeleteEntity` action — params: entity_type, id
- [x] 1.5 Create `Goodwizard.Actions.Brain.ListEntities` action — params: entity_type

## 2. Schema Actions

- [x] 2.1 Create `Goodwizard.Actions.Brain.GetSchema` action — params: entity_type
- [x] 2.2 Create `Goodwizard.Actions.Brain.SaveSchema` action — params: entity_type, schema (map)
- [x] 2.3 Create `Goodwizard.Actions.Brain.ListEntityTypes` action — no required params

## 3. Registration and Testing

- [x] 3.1 Register all brain actions in `Goodwizard.Agent` tools list
- [x] 3.2 Write tests for each brain action
