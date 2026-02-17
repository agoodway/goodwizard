## Context

The agent currently spawns specializedagents with no observability. `Goodwizard.Jido.agent_count()` returns a count but no metadata. There's no way for the main agent to tell the user "the researcher is still working" or "the coder just finished."

Elixir's `:telemetry` library is already a transitive dependency. Jido emits its own telemetry events. Adding custom events for specializedagent lifecycle is the standard approach.

## Goals / Non-Goals

**Goals:**
- Emit structured telemetry events for specializedagent spawn/complete/error
- Maintain a lightweight registry of active specializedagent metadata in Cache
- Provide a Status action the main agent can call to check progress
- Enable channel-specific rendering of specializedagent activity (future: Telegram inline updates)

**Non-Goals:**
- Persistent telemetry storage or metrics aggregation
- Historical query of past specializedagent runs (session logs cover this)
- Real-time streaming of specializedagent output to the user

## Decisions

### 1. Telemetry events under `[:goodwizard, :specializedagent, *]` namespace

**Choice**: Four events:

| Event | Measurements | Metadata |
|-------|-------------|----------|
| `[:goodwizard, :specializedagent, :spawn]` | `%{}` | `%{agent_id, role, task}` |
| `[:goodwizard, :specializedagent, :complete]` | `%{duration_ms}` | `%{agent_id, role, task, status}` |
| `[:goodwizard, :specializedagent, :error]` | `%{duration_ms}` | `%{agent_id, role, task, reason}` |
| `[:goodwizard, :specializedagent, :timeout]` | `%{duration_ms}` | `%{agent_id, role, task}` |

**Rationale**: Follows `:telemetry` conventions. Metadata carries enough context for both machine processing and human-readable status.

### 2. Active agent registry via Cache

**Choice**: On spawn, write `Cache.put("specializedagent:active:#{agent_id}", metadata)`. On complete/error, `Cache.delete("specializedagent:active:#{agent_id}")`. The Status action reads all keys matching `"specializedagent:active:*"`.

**Rationale**: Cache (Nebulex ETS) is already available, fast, and process-safe. No new infrastructure needed. TTL on entries provides automatic cleanup if a specializedagent dies without emitting complete/error.

**Alternative considered**: A dedicated GenServer registry. Rejected as overkill — Cache with TTL handles the common case and is simpler.

### 3. Status action returns structured snapshot

**Choice**: `check_specializedagent_status` action returns:

```elixir
%{
  active: [
    %{agent_id: "specializedagent:123", role: "researcher", task: "Find...", elapsed_ms: 45000}
  ],
  count: 1,
  limit: 5
}
```

**Rationale**: Gives the main agent enough context to report status to the user naturally. Including `limit` helps the agent decide whether to spawn more.

### 4. Telemetry handler attached at application startup

**Choice**: `Goodwizard.SubagentTelemetry` module defines handler functions. Attached via `:telemetry.attach_many/4` in `application.ex` startup.

**Rationale**: Standard pattern. Handlers update Cache entries. Detached automatically on app shutdown.

## Risks / Trade-offs

- **Cache key enumeration** — Nebulex doesn't have a native "list keys by prefix" operation. Mitigation: maintain a separate `"specializedagent:active_ids"` set in Cache that tracks active agent IDs, used by the Status action to look up individual entries.
