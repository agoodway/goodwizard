## ADDED Requirements

### Requirement: Heartbeat vs cron guidance in system prompt
The workspace bootstrap file `TOOLS.md` SHALL include a "Scheduling & Monitoring" section that explains when to use heartbeat checks vs scheduled tasks, so the agent can make informed routing decisions.

#### Scenario: Agent receives scheduling guidance
- **WHEN** the agent's system prompt is hydrated from workspace bootstrap files
- **THEN** the system prompt SHALL include guidance on when to use heartbeat (batched periodic checks, context-aware, conversational continuity) vs cron (exact timing, isolated execution, model override, one-time task)

### Requirement: Heartbeat guidance content
The heartbeat guidance SHALL explain the following use cases and advantages:

- **Use cases**: Multiple periodic checks, context-aware decisions, conversational continuity, low-overhead monitoring
- **Advantages**: Batches multiple checks in one turn, reduces API calls vs multiple scheduled tasks, context-aware prioritization, smart suppression (HEARTBEAT_OK), natural timing

#### Scenario: Agent asked to monitor multiple things
- **WHEN** the user asks the agent to periodically check inbox, calendar, and project status
- **THEN** the agent SHALL prefer adding heartbeat checks over creating 3 separate scheduled tasks

### Requirement: Cron guidance content
The cron guidance SHALL explain the following use cases and advantages:

- **Use cases**: Exact timing required, standalone tasks, different model/thinking needs, one-time task reminders, noisy/frequent tasks, external triggers
- **Advantages**: Exact cron timing, session isolation, model overrides, delivery control, immediate delivery, no agent context needed, one-time task support

#### Scenario: Agent asked to send report at exact time
- **WHEN** the user asks the agent to send a report at exactly 9:00 AM every Monday
- **THEN** the agent SHALL prefer creating a scheduled task over adding a heartbeat check
