## 1. Signal Types

- [ ] 1.1 Define signal type constants in a `Goodwizard.Subagent.Signals` module: `@progress "goodwizard.subagent.progress"`, `@result "goodwizard.subagent.result"`, `@error "goodwizard.subagent.error"`
- [ ] 1.2 Document signal data shapes in module docs — each signal carries `%{agent_id, role, ...}` with type-specific fields

## 2. SubagentRouter Plugin

- [ ] 2.1 Create `lib/goodwizard/plugins/subagent_router.ex` using `Jido.Plugin` with signal patterns matching `"goodwizard.subagent.*"` and `"jido.agent.child.*"`
- [ ] 2.2 Handle `goodwizard.subagent.progress` — write to `Cache.put("subagent:progress:#{agent_id}", data)`
- [ ] 2.3 Handle `goodwizard.subagent.result` — write to `Cache.put("subagent:result:#{agent_id}", data)`, delete progress entry
- [ ] 2.4 Handle `goodwizard.subagent.error` — write to `Cache.put("subagent:result:#{agent_id}", %{error: reason})`, delete progress entry
- [ ] 2.5 Handle `jido.agent.child.exit` — if no result entry exists for the agent_id, write an error entry as safety net for unclean exits
- [ ] 2.6 Add `SubagentRouter` to plugins list in `Goodwizard.Agent`

## 3. EmitProgress Action

- [ ] 3.1 Create `lib/goodwizard/actions/subagent/emit_progress.ex` with schema `%{message: string}`
- [ ] 3.2 Implement `run/2` — build signal with `agent_id`, `role` (from `context.agent_id` or agent state), and `message`; return `{:ok, %{emitted: true}, [Directive.emit_to_parent(signal)]}`
- [ ] 3.3 Add `EmitProgress` to SubAgent's tools list

## 4. Switch Spawn to SpawnAgent Directive

- [ ] 4.1 Add optional `async` parameter (boolean, default false) to Spawn action schema
- [ ] 4.2 Replace `Goodwizard.Jido.start_agent` + `Task.Supervisor.async` + `ask_sync` with emitting a `Directive.SpawnAgent` and a task signal to the child
- [ ] 4.3 Implement sync mode — after emitting directives, poll `Cache.get("subagent:result:#{agent_id}")` with 500ms interval until result appears or timeout
- [ ] 4.4 Implement async mode — emit directives and return `{:ok, %{agent_id: id, role: role, status: :running}}` immediately
- [ ] 4.5 Preserve cleanup — on sync timeout or error, emit `Directive.StopChild` to terminate the subagent

## 5. SubAgent Parent Awareness

- [ ] 5.1 Update `SubAgent.on_before_cmd/2` to read `__parent__` from agent state and make it available for `EmitProgress` to use when building `emit_to_parent` directives
- [ ] 5.2 On ReAct completion, emit a `goodwizard.subagent.result` signal to parent with the final result
- [ ] 5.3 On ReAct error, emit a `goodwizard.subagent.error` signal to parent with the error reason

## 6. Tests

- [ ] 6.1 Test: SubagentRouter handles progress signal and writes to Cache
- [ ] 6.2 Test: SubagentRouter handles result signal, writes to Cache, cleans up progress entry
- [ ] 6.3 Test: SubagentRouter handles child.exit for unclean exits
- [ ] 6.4 Test: EmitProgress action builds correct signal with agent metadata
- [ ] 6.5 Test: Spawn in sync mode polls Cache and returns result when available
- [ ] 6.6 Test: Spawn in sync mode returns error on timeout
- [ ] 6.7 Test: Spawn in async mode returns immediately with agent_id
- [ ] 6.8 Test: Result signal ordering — result written after progress does not get overwritten
