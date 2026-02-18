## ADDED Requirements

### Requirement: List all active scheduled tasks

The system SHALL provide a `Goodwizard.Actions.Scheduling.ListScheduledTasks` action that reads all active scheduled tasks from the `AgentServer` state's `scheduled_task_jobs` map and returns them as a list of job descriptors. The action SHALL use `use Jido.Action` with name `list_scheduled_tasks`, an empty schema (no required parameters), and a `run/2` callback that retrieves scheduled tasks from the agent server.

#### Scenario: Multiple active jobs are listed

- **WHEN** `ListScheduledTasks` is called and the agent has 3 active scheduled tasks
- **THEN** it SHALL return `{:ok, %{jobs: [job1, job2, job3], count: 3}}` where each job is a map containing `job_id`, `schedule`, `task`, and `room_id`

#### Scenario: No active jobs returns empty list

- **WHEN** `ListScheduledTasks` is called and the agent has no active scheduled tasks
- **THEN** it SHALL return `{:ok, %{jobs: [], count: 0}}`

### Requirement: Job descriptor format includes all identifying fields

Each entry in the returned jobs list SHALL include `job_id` (string representation of the atom), `schedule` (string, the cron expression), `task` (string, the task description), and `room_id` (string, the target room identifier).

#### Scenario: Job descriptor contains all four fields

- **WHEN** a scheduled task was scheduled with schedule `"0 9 * * *"`, task `"Daily report"`, and room_id `"cli:heartbeat"`
- **THEN** the corresponding job descriptor in the list SHALL contain `%{job_id: "scheduled_task_12345678", schedule: "0 9 * * *", task: "Daily report", room_id: "cli:heartbeat"}`

### Requirement: ListScheduledTasks is registered in the Agent tools list

The `Goodwizard.Actions.Scheduling.ListScheduledTasks` module SHALL be added to the `tools:` list in `Goodwizard.Agent`, alongside the existing `Goodwizard.Actions.Scheduling.ScheduledTask` action.

#### Scenario: Agent starts with list_scheduled_tasks tool available

- **WHEN** the agent is initialized
- **THEN** `list_scheduled_tasks` SHALL appear in the agent's available tool list
