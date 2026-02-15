## Why

The `brain-foundation` and `brain-entity-storage` changes deliver a programmatic Elixir API for schema-validated entity CRUD. But the Goodwizard agent can only invoke functionality through Jido actions. This change creates thin action wrappers that expose the Brain API to the agent and registers them in the agent's tool list.

## What Changes

- Create 8 Jido action modules under `Goodwizard.Actions.Brain.*` that delegate to `Goodwizard.Brain`
- Register all brain actions in `Goodwizard.Agent` tools list

## Capabilities

### New Capabilities
- `brain-agent-tools`: 8 Jido actions (CreateEntity, ReadEntity, UpdateEntity, DeleteEntity, ListEntities, GetSchema, SaveSchema, ListEntityTypes) registered as agent tools

### Modified Capabilities
- `agent-tools`: Agent tool list expanded with brain actions

## Impact

- **Dependencies**: None — uses modules from `brain-foundation` and `brain-entity-storage`
- **Agent tools**: 8 new Jido actions registered in agent tool list
- **Existing code**: Modifies `Goodwizard.Agent` to add brain actions to tool list
- **Depends on**: `brain-entity-storage` (which depends on `brain-foundation`)
