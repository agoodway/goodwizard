## ADDED Requirements

### Requirement: List all active cron jobs

The system SHALL provide a `Goodwizard.Actions.Scheduling.ListCronJobs` action that reads all active cron jobs from the `AgentServer` state's `cron_jobs` map and returns them as a list of job descriptors. The action SHALL use `use Jido.Action` with name `list_cron_jobs`, an empty schema (no required parameters), and a `run/2` callback that retrieves cron jobs from the agent server.

#### Scenario: Multiple active jobs are listed

- **WHEN** `ListCronJobs` is called and the agent has 3 active cron jobs
- **THEN** it SHALL return `{:ok, %{jobs: [job1, job2, job3], count: 3}}` where each job is a map containing `job_id`, `schedule`, `task`, and `room_id`

#### Scenario: No active jobs returns empty list

- **WHEN** `ListCronJobs` is called and the agent has no active cron jobs
- **THEN** it SHALL return `{:ok, %{jobs: [], count: 0}}`

### Requirement: Job descriptor format includes all identifying fields

Each entry in the returned jobs list SHALL include `job_id` (string representation of the atom), `schedule` (string, the cron expression), `task` (string, the task description), and `room_id` (string, the target room identifier).

#### Scenario: Job descriptor contains all four fields

- **WHEN** a cron job was scheduled with schedule `"0 9 * * *"`, task `"Daily report"`, and room_id `"cli:heartbeat"`
- **THEN** the corresponding job descriptor in the list SHALL contain `%{job_id: "cron_12345678", schedule: "0 9 * * *", task: "Daily report", room_id: "cli:heartbeat"}`

### Requirement: ListCronJobs is registered in the Agent tools list

The `Goodwizard.Actions.Scheduling.ListCronJobs` module SHALL be added to the `tools:` list in `Goodwizard.Agent`, alongside the existing `Goodwizard.Actions.Scheduling.Cron` action.

#### Scenario: Agent starts with list_cron_jobs tool available

- **WHEN** the agent is initialized
- **THEN** `list_cron_jobs` SHALL appear in the agent's available tool list
