## Context

After `specializedagent-workspace-discovery`, the agent has a map of specializedagent configs in `agent.state.specializedagents.agents`. The Spawn action needs to look up a config by name and pass it to the SubAgent process. The SubAgent module currently uses `use JidoAi.ReActAgent` with compile-time `tools:` and `model:` — these need to become runtime-configurable.

The key constraint from CLAUDE.md: Jido does NOT propagate `agent.state` into action context. The Spawn action must read configs from `Goodwizard.Cache` (populated by the plugin) rather than relying on context state.

## Goals / Non-Goals

**Goals:**
- Spawn action resolves named configs and passes them to SubAgent
- SubAgent character, tools, model, and iteration limits are config-driven
- Backwards compatible — omitting `agent_name` uses the generic default
- Tool categories resolve to concrete module lists at spawn time

**Non-Goals:**
- Runtime modification of specializedagent configs (hot-reload)
- Per-spawn tool overrides beyond what the config defines
- Subagent-to-specializedagent communication (covered by a separate proposal)

## Decisions

### 1. Config resolution via Cache, not context.state

**Choice**: Spawn action reads from `Goodwizard.Cache.get("specializedagents:list")` with a fallback to `Goodwizard.Plugins.Subagents.scan/1` on cache miss.

**Rationale**: Jido doesn't propagate agent state into action context (CLAUDE.md). Cache is the reliable path. The plugin populates cache on mount; this action reads from it.

### 2. SubAgent accepts runtime opts via start_agent options

**Choice**: Pass config as `initial_state` when calling `Goodwizard.Jido.start_agent/2`:

```elixir
Goodwizard.Jido.start_agent(SubAgent,
  id: agent_id,
  initial_state: %{
    role_config: config  # from workspace discovery
  }
)
```

SubAgent's `on_before_cmd` reads `agent.state.role_config` to build character and select tools.

**Rationale**: Jido's `start_agent` accepts `initial_state` which is set on the agent struct before any hooks run. This avoids needing to modify the SubAgent macro invocation at runtime.

### 3. Tool category resolver as a separate module

**Choice**: `Goodwizard.Actions.Subagent.ToolResolver` maps category atoms to module lists:

```elixir
def resolve(:filesystem), do: [ReadFile, WriteFile, ListDir]
def resolve(:shell), do: [Exec]
def resolve(:brain), do: [CreateEntity, ReadEntity, UpdateEntity, ...]
def resolve(:memory), do: [ReadLongTerm, WriteLongTerm, ...]
def resolve(:messaging), do: [Send]
def resolve(:scheduling), do: [Cron, CancelCron, ListCronJobs]
def resolve(:browser), do: [JidoBrowser actions...]
```

**Rationale**: Single source of truth for tool-to-category mapping. Easy to extend when new actions are added. Keeps Spawn action clean.

### 4. Character constructed from config, not hardcoded module

**Choice**: `SubAgent.Character.from_config/1` builds a `Jido.Character` from the workspace config map — name, description, traits from frontmatter; instructions from body. Falls back to current hardcoded defaults when no config is provided.

**Rationale**: The existing `SubAgent.Character` module uses `use Jido.Character, defaults: %{...}`. Adding a `from_config/1` function preserves the default path while enabling config-driven construction.

## Risks / Trade-offs

- **Tool list mismatch** — If a config references a tool category that doesn't exist, the resolver should warn and skip rather than crash. Log a warning so the user can fix their config.
- **Model cost** — Configs can specify any model. A specializedagent config using `anthropic:claude-opus-4-6` would be expensive. No guard rails here — trust the user.
