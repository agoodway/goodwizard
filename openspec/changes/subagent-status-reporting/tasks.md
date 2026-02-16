## 1. Telemetry Events

- [ ] 1.1 Create `lib/goodwizard/subagent_telemetry.ex` with handler functions for `[:goodwizard, :subagent, :spawn]`, `[:goodwizard, :subagent, :complete]`, `[:goodwizard, :subagent, :error]`, `[:goodwizard, :subagent, :timeout]`
- [ ] 1.2 Spawn handler writes active metadata to Cache under `"subagent:active:#{agent_id}"` with 5-minute TTL (safety net); also adds agent_id to `"subagent:active_ids"` MapSet in Cache
- [ ] 1.3 Complete/error/timeout handlers remove metadata from Cache and remove agent_id from active_ids set

## 2. Emit Events from Spawn Actions

- [ ] 2.1 Add `:telemetry.execute([:goodwizard, :subagent, :spawn], ...)` call in `Spawn.spawn_and_run/1` after successful `start_agent`
- [ ] 2.2 Add `:telemetry.execute([:goodwizard, :subagent, :complete], ...)` on successful result
- [ ] 2.3 Add `:telemetry.execute([:goodwizard, :subagent, :error], ...)` on failure
- [ ] 2.4 Add `:telemetry.execute([:goodwizard, :subagent, :timeout], ...)` on Task.await timeout
- [ ] 2.5 Add same telemetry calls to `SpawnMany` for each individual subagent in the batch

## 3. Status Action

- [ ] 3.1 Create `lib/goodwizard/actions/subagent/status.ex` with `use Jido.Action`, name `check_subagent_status`, empty schema
- [ ] 3.2 Implement `run/2` — read `"subagent:active_ids"` from Cache, look up each active entry, compute elapsed time, return structured snapshot
- [ ] 3.3 Include `count` and `limit` (from config or constant) in response

## 4. Application Startup

- [ ] 4.1 Attach telemetry handlers via `:telemetry.attach_many/4` in `Goodwizard.Application.start/2`

## 5. Agent Registration

- [ ] 5.1 Add `Goodwizard.Actions.Subagent.Status` to tools list in `Goodwizard.Agent`

## 6. Tests

- [ ] 6.1 Test: spawn telemetry event fires with correct metadata
- [ ] 6.2 Test: complete telemetry event includes duration_ms
- [ ] 6.3 Test: Status action returns empty list when no subagents active
- [ ] 6.4 Test: Status action returns active subagent metadata after spawn event
- [ ] 6.5 Test: Complete event removes subagent from active registry
