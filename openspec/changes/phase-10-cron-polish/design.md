## Context

Phase 10 is the final integration and hardening phase of Goodwizard. Phases 1–9 deliver a working agent with CLI and Telegram channels, memory persistence, prompt skills, web tools, and subagent spawning. What's missing: the agent cannot act autonomously on a schedule, there are no operational mix tasks for starting the full system or inspecting its state, and production concerns (structured logging, error handling, graceful shutdown, config validation) have been deferred.

This phase adds two autonomous capabilities (cron scheduling and heartbeat) and then sweeps through the entire codebase to add the operational polish required for reliable production use.

**Prerequisites**: Phase 8 (Telegram Channel) and Phase 9 (Web + Subagents) must be complete — the cron action targets any channel, heartbeat processes messages through the agent pipeline, and the polish work touches all modules.

## Goals / Non-Goals

**Goals:**

- Enable the agent to execute tasks on a cron schedule via Jido's directive system
- Enable periodic autonomous action via a heartbeat that reads HEARTBEAT.md from the workspace
- Provide `mix goodwizard.start` to launch all enabled channels in one command
- Provide `mix goodwizard.status` to inspect running system state
- Add structured Logger calls throughout all modules for observability
- Harden ReAct lifecycle hooks against LLM timeouts, tool crashes, and malformed responses
- Implement graceful shutdown that saves active sessions before exit
- Validate configuration at startup and warn about missing or invalid values

**Non-Goals:**

- Building a cron management UI or REST API
- Distributed scheduling across multiple nodes
- Metrics/telemetry export (OpenTelemetry, StatsD, etc.)
- Hot config reload without restart
- Automated recovery or retry of failed scheduled tasks

## Decisions

### 1. Cron action emits Directive.Schedule rather than managing its own timer

**Decision**: `Goodwizard.Actions.Scheduling.Cron` validates the cron expression and emits a `Directive.Schedule`. Jido's built-in Scheduler handles the actual timer management and task dispatch.

**Rationale**: Jido already provides a scheduler that understands directives. Duplicating timer management in the action would create a parallel scheduling system. By emitting a directive, the action stays stateless and testable — it just transforms input into a scheduling instruction.

**Alternatives considered**: A custom GenServer-based scheduler was considered but rejected because it would bypass Jido's supervision and directive lifecycle.

### 2. Heartbeat as a GenServer under Application supervisor, targeting a Messaging room

**Decision**: Implement heartbeat as a dedicated GenServer (`Goodwizard.Heartbeat`) started under the Application supervisor, using `Process.send_after/3` for periodic ticks. Saves heartbeat messages to a Messaging room.

**Rationale**: The heartbeat has a simple job — read a file and send it through the agent pipeline on a schedule. A GenServer with `send_after` is straightforward. It starts under the Application supervisor (not a ChannelSupervisor, which has been replaced by `Goodwizard.Messaging`). The heartbeat targets a configurable Messaging room rather than a raw channel+chat_id, consistent with the room_id pattern used throughout.

**Alternatives considered**: Jido Sensor was considered but adds abstraction overhead for a simple periodic read. A bare Task was rejected because it needs supervised restarts and state (last-read timestamp, schedule interval).

### 3. mix goodwizard.start delegates to Application with channel auto-detection

**Decision**: `mix goodwizard.start` calls `Application.ensure_all_started(:goodwizard)` and then blocks. The Application module reads config to determine which channels are enabled — the Telegram handler is a static application child when enabled, and the CLI is started directly.

**Rationale**: Channel auto-detection already exists in the Application module (Phase 8 for Telegram as a static child). There is no ChannelSupervisor — `Goodwizard.Messaging` handles room/channel supervision. The mix task just needs to start the app and keep the process alive.

**Alternatives considered**: Passing channel flags to the mix task (`--cli --telegram`) was considered but rejected in favor of config-driven behavior — the config.toml already declares which channels are enabled.

### 4. mix goodwizard.status queries Messaging for rooms/messages/instances

**Decision**: The status task starts the application, then queries Config, `Goodwizard.Messaging` (for rooms, messages, and channel instances), and agent processes via GenServer.call to gather runtime state.

**Rationale**: Querying live processes gives accurate real-time data. `Goodwizard.Messaging` provides room and message counts, and InstanceServer provides channel instance status. The alternative of reading config files only shows static configuration, not actual running state.

### 5. Structured logging uses Logger metadata, not custom formatters

**Decision**: Add `Logger.info/warning/error` calls with metadata maps throughout all modules. Use the default Logger backend — no custom formatter or structured logging library.

**Rationale**: Elixir's built-in Logger with metadata is sufficient for a single-node application. Custom formatters or JSON logging can be added later by users via Logger configuration without code changes. The goal is observability, not log aggregation infrastructure.

**Alternatives considered**: Adding `jason`-based JSON log formatting was considered but rejected as over-engineering for the current scope.

### 6. Error handling wraps ReAct hooks with rescue/catch, returns error strings

**Decision**: Wrap `on_before_cmd/2` and `on_after_cmd/3` in try/rescue blocks. Caught errors are logged and returned as error strings for LLM consumption. The agent continues operating after a hook error.

**Rationale**: Actions already return `{:error, "message"}` strings for LLM readability. Hook errors should follow the same pattern. Crashing the agent process on a hook error would terminate the conversation, which is worse than a degraded response.

**Alternatives considered**: Letting errors crash and relying on supervisor restarts was considered but rejected — it destroys the conversation session and provides no feedback to the user.

### 7. Graceful shutdown traps exits in Application and flushes sessions

**Decision**: Set `Process.flag(:trap_exit, true)` in the Application supervisor. Implement a `terminate/2` callback that iterates active agent processes and calls their session-save logic before shutdown completes.

**Rationale**: JSONL session persistence (Phase 6) appends on each turn, so most data is already on disk. The graceful shutdown ensures the final in-flight turn is saved and metadata is flushed. Without it, a SIGTERM during an active conversation loses the last exchange.

### 8. Config validation checks Telegex token via Application.get_env

**Decision**: Add a `Goodwizard.Config.validate!/0` call early in `Application.start/2`. It checks required keys per enabled feature — for Telegram, it checks `Application.get_env(:telegex, :token)` (not `TELEGRAM_BOT_TOKEN` via Config, since the token is managed by Telegex). Validation warns but does not crash — the app starts in a degraded state.

**Rationale**: Crashing on missing optional config (e.g., Telegram token when only CLI is used) would be overly strict. Warning lets the operator see what's misconfigured while still running available features. The Telegex token is checked via `Application.get_env(:telegex, :token)` because it's wired in `runtime.exs`, not through `Goodwizard.Config`.

**Alternatives considered**: Raising on any invalid config was considered but rejected — it prevents starting the app for partial configurations that are valid for the enabled feature set.

## Risks / Trade-offs

**Cron expression validation is shallow** → The action validates format but relies on Jido's scheduler for semantic correctness. If Jido rejects a valid-looking expression, the error surfaces at schedule time, not at action time. Mitigation: document supported cron syntax.

**Heartbeat file-watch is poll-based** → Reading HEARTBEAT.md on a timer means changes aren't detected instantly. Mitigation: default interval of 5 minutes is acceptable for the "autonomous nudge" use case. Users can configure shorter intervals.

**Graceful shutdown has a timeout** → If session save takes too long (e.g., LLM call in flight), the OS will SIGKILL after the shutdown timeout. Mitigation: set a reasonable shutdown timeout (30s) and skip in-flight LLM calls — only flush what's already in memory.

**Logging sweep is broad but shallow** → Adding Logger calls to all modules improves observability but doesn't add structured error codes or correlation IDs. Mitigation: the logging infrastructure supports adding metadata later without changing call sites.

**Config validation is warn-only** → Missing API keys won't prevent startup, which could lead to confusing runtime errors. Mitigation: validation warnings are prominent (Logger.warning level) and include actionable fix instructions.
