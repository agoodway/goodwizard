## MODIFIED Requirements

### Requirement: Agent tool list includes workflow actions

The `Goodwizard.Agent` module SHALL include `Goodwizard.Actions.Workflow.Run` and `Goodwizard.Actions.Workflow.Resume` in its registered tool list.

#### Scenario: Workflow Run tool is available to agent

- **WHEN** the agent is started
- **THEN** the `workflow_run` tool is available in the agent's tool list

#### Scenario: Workflow Resume tool is available to agent

- **WHEN** the agent is started
- **THEN** the `workflow_resume` tool is available in the agent's tool list
