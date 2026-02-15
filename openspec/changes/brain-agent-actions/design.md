## Context

This change builds on `brain-foundation` (Paths, Id, Schema, Seeds) and `brain-entity-storage` (Entity format, Brain CRUD API). Those changes provide a complete programmatic API for managing schema-validated entities. This change wraps that API in Jido actions so the Goodwizard agent can invoke brain operations.

## Goals / Non-Goals

**Goals:**
- Create thin Jido action modules that delegate to `Goodwizard.Brain` functions
- Register all brain actions in the agent's tool list
- Follow existing action patterns in the codebase

**Non-Goals:**
- Business logic changes — all logic lives in `Brain` and its submodules
- Search or query actions (future enhancement)
- Relationship traversal actions (future enhancement)

## Decisions

### 1. Action module structure

Each action follows the existing Jido action pattern: define params schema, implement `run/2`, delegate to `Goodwizard.Brain`.

```
Goodwizard.Actions.Brain.CreateEntity   — params: entity_type, data (map), body (optional string)
Goodwizard.Actions.Brain.ReadEntity     — params: entity_type, id
Goodwizard.Actions.Brain.UpdateEntity   — params: entity_type, id, data (map), body (optional string)
Goodwizard.Actions.Brain.DeleteEntity   — params: entity_type, id
Goodwizard.Actions.Brain.ListEntities   — params: entity_type
Goodwizard.Actions.Brain.GetSchema      — params: entity_type
Goodwizard.Actions.Brain.SaveSchema     — params: entity_type, schema (map)
Goodwizard.Actions.Brain.ListEntityTypes — no required params
```

**Rationale**: Follows existing patterns — thin action modules that delegate to a domain module (like filesystem actions delegate to `Filesystem.resolve_path`). The `Brain` module is the core logic; actions are the agent-facing interface.

### 2. Agent registration

All 8 actions are added to the tools list in `Goodwizard.Agent`. They are grouped together under a `# Brain` comment section, following the existing organization pattern.

### 3. Workspace resolution

Each action resolves the workspace path from the agent's config (same pattern as filesystem actions), then passes it to `Brain` functions.

## Risks / Trade-offs

- **[Thin wrappers]** — Actions are intentionally thin. If they become too boilerplate-heavy, consider a macro. But 8 actions is manageable without abstraction.
