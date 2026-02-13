# Phase 10: Cron, Heartbeat, and Polish — Tasks

## Backend

- [ ] 1.1 Create Goodwizard.Actions.Scheduling.Cron action (cron expression + task + channel/chat_id, emit Directive.Schedule)
- [ ] 1.2 Create heartbeat GenServer/Sensor — read HEARTBEAT.md on schedule, process as agent message
- [ ] 1.3 Create Mix.Tasks.Goodwizard.Start — start full application with all enabled channels
- [ ] 1.4 Create Mix.Tasks.Goodwizard.Status — show config, active channels, conversations, memory stats
- [ ] 1.5 Add structured Logger calls throughout all modules
- [ ] 1.6 Add error handling in ReAct lifecycle hooks — catch LLM timeouts, tool crashes, malformed responses
- [ ] 1.7 Implement graceful shutdown — trap exit in Application, save sessions on termination
- [ ] 1.8 Add config validation at startup — warn missing API keys, invalid model strings

## Test

- [ ] 2.1 Test Cron action emits correct schedule directive
- [ ] 2.2 Test heartbeat reads HEARTBEAT.md and processes message
- [ ] 2.3 Test status task reports correct system state
- [ ] 2.4 Test graceful shutdown saves active sessions
