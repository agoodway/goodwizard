# Phase 10: Scheduled Tasks, Heartbeat, and Polish — Tasks

## Backend

- [x] 1.1 Create Goodwizard.Actions.Scheduling.ScheduledTask action (cron expression + task + room_id, emit Directive.Schedule)
- [x] 1.2 Create Goodwizard.Heartbeat GenServer under Application supervisor — read HEARTBEAT.md on schedule, target configurable Messaging room
- [x] 1.3 Create Mix.Tasks.Goodwizard.Start — start full application with all enabled channels
- [x] 1.4 Create Mix.Tasks.Goodwizard.Status — show config, active channels, conversations, memory stats
- [x] 1.5 Add structured Logger calls throughout all modules
- [x] 1.6 Add error handling in ReAct lifecycle hooks — catch LLM timeouts, tool crashes, malformed responses
- [x] 1.7 Implement graceful shutdown — trap exit in Application, save sessions on termination
- [x] 1.8 Add config validation at startup — warn missing API keys, invalid model strings

## Test

- [x] 2.1 Test Scheduled task action emits correct schedule directive
- [x] 2.2 Test heartbeat reads HEARTBEAT.md and processes message
- [x] 2.3 Test status task reports correct system state
- [x] 2.4 Test graceful shutdown saves active sessions
