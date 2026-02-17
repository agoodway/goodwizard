## 1. SpawnMany Action

- [ ] 1.1 Create `lib/goodwizard/actions/specializedagent/spawn_many.ex` with `use Jido.Action`, name `spawn_specializedagents`, schema: `tasks` (required list of maps), `strategy` (optional, default `:all`)
- [ ] 1.2 Validate each task entry has a `task` string; `agent_name` and `label` are optional
- [ ] 1.3 Check concurrency — count active agents via `Goodwizard.Jido.agent_count()`, reject if `active + length(tasks) > max_concurrent_specializedagents`; include available slot count in error
- [ ] 1.4 Resolve configs for each task — reuse config resolution from shared helpers
- [ ] 1.5 Emit `Directive.SpawnAgent` for each task (building on signal-based spawn from `specializedagent-signal-communication`)
- [ ] 1.6 Implement `:all` strategy — poll Cache for `"specializedagent:result:#{agent_id}"` entries for all spawned agents until all results arrive or timeout
- [ ] 1.7 Implement `:any` strategy — poll Cache until first result arrives, then emit `Directive.StopChild` for remaining agents
- [ ] 1.8 Aggregate results into `%{results: [%{label: string, status: :ok | :error, result: any}]}` preserving task order
- [ ] 1.9 Guaranteed cleanup — emit `Directive.StopChild` for all spawned agents on completion or error

## 2. Agent Registration

- [ ] 2.1 Add `Goodwizard.Actions.Subagent.SpawnMany` to tools list in `Goodwizard.Agent`

## 3. Shared Helpers

- [ ] 3.1 Extract config resolution logic into `Goodwizard.Actions.Subagent.Helpers` so `Spawn`, `SpawnMany`, and future actions share the same resolution path
- [ ] 3.2 Extract Cache polling logic (wait-for-result loop) into a shared helper both `Spawn` (sync mode) and `SpawnMany` can call

## 4. Tests

- [ ] 4.1 Test: SpawnMany with 2 tasks spawns both and returns both results (`:all` strategy)
- [ ] 4.2 Test: SpawnMany with `:any` strategy returns first completed result and stops remaining agents
- [ ] 4.3 Test: SpawnMany respects concurrency limit — returns error with available slot count when over limit
- [ ] 4.4 Test: SpawnMany cleans up all agents on success
- [ ] 4.5 Test: SpawnMany cleans up all agents on partial failure
- [ ] 4.6 Test: SpawnMany with named agents resolves configs correctly
