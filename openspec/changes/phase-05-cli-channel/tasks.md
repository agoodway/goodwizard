# Phase 5: CLI Channel — Tasks

## Backend

- [ ] 1.1 Create Goodwizard.ChannelSupervisor (DynamicSupervisor with start_channel/2)
- [ ] 1.2 Create Goodwizard.Channels.CLI.Server GenServer — init starts AgentServer via Jido instance, REPL loop in linked Task
- [ ] 1.3 Implement message handling — call Agent.ask_sync/3, print response
- [ ] 1.4 Update Goodwizard.Application supervision tree to include ChannelSupervisor
- [ ] 1.5 Create Mix.Tasks.Goodwizard.Setup — create workspace dirs and default config.toml
- [ ] 1.6 Create Mix.Tasks.Goodwizard.Cli — start app, launch CLI channel, keep alive

## Test

- [ ] 2.1 Test CLI server starts and initializes agent with correct state
- [ ] 2.2 Test message processing returns response (with mocked LLM)
- [ ] 2.3 Test setup task creates workspace dirs and config file
