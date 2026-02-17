## 1. Tool Category Resolver

- [ ] 1.1 Create `lib/goodwizard/actions/specializedagent/tool_resolver.ex` with `resolve/1` that maps category atoms (`:filesystem`, `:shell`, `:brain`, `:memory`, `:messaging`, `:scheduling`, `:browser`) to lists of action modules
- [ ] 1.2 Add `resolve_many/1` that takes a list of category atoms and returns a flat, deduplicated list of action modules
- [ ] 1.3 Handle unknown categories — log warning and return empty list

## 2. Spawn Action Updates

- [ ] 2.1 Add optional `agent_name` parameter to `Spawn` action schema
- [ ] 2.2 Add config resolution — when `agent_name` is provided, read from `Goodwizard.Cache.get("specializedagents:list")`, fall back to `Goodwizard.Plugins.Subagents.scan/1` on cache miss
- [ ] 2.3 Pass resolved config as `initial_state.role_config` when starting the SubAgent
- [ ] 2.4 Use config's `timeout` value (with fallback to current `@ask_timeout`) for the Task.await
- [ ] 2.5 Return error with available agent names when `agent_name` doesn't match any discovered config

## 3. SubAgent Runtime Configuration

- [ ] 3.1 Update `SubAgent.on_before_cmd/2` to check `agent.state.role_config` — if present, use it for character construction; if absent, fall back to current hardcoded behavior
- [ ] 3.2 When role_config is present, resolve tool categories via `ToolResolver.resolve_many/1` and set as the agent's available tools
- [ ] 3.3 When role_config specifies a model, pass it through to the ReAct params

## 4. Character Config Construction

- [ ] 4.1 Add `SubAgent.Character.from_config/1` that builds a `Jido.Character` from a workspace config map — maps frontmatter to character fields, body to instructions
- [ ] 4.2 Ensure `from_config/1` merges config instructions with base safety instructions (no direct user communication, no recursive spawning, stay in scope)

## 5. Tests

- [ ] 5.1 Test: ToolResolver maps each category to correct module list
- [ ] 5.2 Test: ToolResolver handles unknown category gracefully
- [ ] 5.3 Test: Spawn with valid `agent_name` resolves config and passes to SubAgent
- [ ] 5.4 Test: Spawn without `agent_name` falls back to generic SubAgent behavior
- [ ] 5.5 Test: Spawn with unknown `agent_name` returns error listing available agents
- [ ] 5.6 Test: Character.from_config builds character with config values and retains safety instructions
