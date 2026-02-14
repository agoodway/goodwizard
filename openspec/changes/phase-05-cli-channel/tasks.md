# Phase 5: CLI Channel — Tasks

## Backend

- [x] 1.1 Create Goodwizard.Channels.CLI.Server GenServer — init creates Messaging room via `get_or_create_room_by_external_binding(:cli, "goodwizard", "direct")`, starts AgentServer via Jido instance, REPL loop in linked Task
- [x] 1.2 Implement message handling — save user message to room, call Agent.ask_sync/3, save assistant message to room, print response
- [x] 1.3 Create Mix.Tasks.Goodwizard.Setup — create workspace dirs and default config.toml
- [x] 1.4 Create Mix.Tasks.Goodwizard.Cli — start app, launch CLI Server directly, keep alive

## Test

- [x] 2.1 Test CLI server starts, creates Messaging room, and initializes agent with correct state
- [x] 2.2 Test message processing saves to room and returns response (with mocked LLM)
- [x] 2.3 Test setup task creates workspace dirs and config file
