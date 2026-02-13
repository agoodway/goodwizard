# Phase 10: Cron, Heartbeat, and Polish

## Why

Scheduled tasks and heartbeat give the agent autonomous capabilities — it can take action without being prompted. The polish items (logging, error handling, graceful shutdown, config validation) are necessary for production reliability. This phase completes Goodwizard as a fully functional system.

## What

### Cron Action

Schedule recurring tasks via Jido's built-in Scheduler:
- Schema: schedule (cron expression), task (string), channel (required), chat_id (required)
- Emits a `Directive.Schedule` that Jido's scheduler picks up

### Heartbeat

Periodic GenServer (or Jido Sensor) that reads `HEARTBEAT.md` from workspace on a schedule and processes it as a message through the agent.

### Mix Tasks

**mix goodwizard.start** — Start the full application with all enabled channels (CLI + Telegram if configured).

**mix goodwizard.status** — Show config, active channels, active conversations, memory stats.

### Production Polish

- Structured logging with `Logger` throughout all modules
- Error handling in ReAct lifecycle hooks: catch LLM timeouts, tool crashes, malformed responses
- Graceful shutdown: save sessions on termination (trap exit in Application)
- Config validation at startup: warn about missing API keys, invalid model strings

## Dependencies

- Phase 8 (Telegram Channel)
- Phase 9 (Web + Subagents)

## Reference

- This is the final integration and hardening phase
