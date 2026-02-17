## 1. Telemetry Events

- [ ] 1.1 Create `lib/goodwizard/specializedagent_telemetry.ex` with handler functions for `[:goodwizard, :specializedagent, :spawn]`, `[:goodwizard, :specializedagent, :complete]`, `[:goodwizard, :specializedagent, :error]`, `[:goodwizard, :specializedagent, :timeout]`
- [ ] 1.2 Spawn handler writes active metadata to Cache under `"specializedagent:active:#{agent_id}"` with 5-minute TTL (safety net); also adds agent_id to `"specializedagent:active_ids"` MapSet in Cache
- [ ] 1.3 Complete/error/timeout handlers remove metadata from Cache and remove agent_id from active_ids set

## 2. Emit Events from Spawn Actions

- [ ] 2.1 Add `:telemetry.execute([:goodwizard, :specializedagent, :spawn], ...)` call in `Spawn.spawn_and_run/1` after successful `start_agent`
- [ ] 2.2 Add `:telemetry.execute([:goodwizard, :specializedagent, :complete], ...)` on successful result
- [ ] 2.3 Add `:telemetry.execute([:goodwizard, :specializedagent, :error], ...)` on failure
- [ ] 2.4 Add `:telemetry.execute([:goodwizard, :specializedagent, :timeout], ...)` on Task.await timeout
- [ ] 2.5 Add same telemetry calls to `SpawnMany` for each individual specializedagent in the batch

## 3. Status Action

- [ ] 3.1 Create `lib/goodwizard/actions/specializedagent/status.ex` with `use Jido.Action`, name `check_specializedagent_status`, empty schema
- [ ] 3.2 Implement `run/2` — read `"specializedagent:active_ids"` from Cache, look up each active entry, compute elapsed time, return structured snapshot
- [ ] 3.3 Include `count` and `limit` (from config or constant) in response

## 4. Application Startup

- [ ] 4.1 Attach telemetry handlers via `:telemetry.attach_many/4` in `Goodwizard.Application.start/2`

## 5. Agent Registration

- [ ] 5.1 Add `Goodwizard.Actions.Subagent.Status` to tools list in `Goodwizard.Agent`

## 6. Tests

- [ ] 6.1 Test: spawn telemetry event fires with correct metadata
- [ ] 6.2 Test: complete telemetry event includes duration_ms
- [ ] 6.3 Test: Status action returns empty list when no specializedagents active
- [ ] 6.4 Test: Status action returns active specializedagent metadata after spawn event
- [ ] 6.5 Test: Complete event removes specializedagent from active registry
