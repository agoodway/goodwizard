## ADDED Requirements

### Requirement: Resume action accepts token and decision

The `Goodwizard.Actions.Workflow.Resume` action SHALL accept a `token` parameter (string) and an `approve` parameter (boolean).

#### Scenario: Resume with approve continues pipeline

- **WHEN** the Resume action receives `token: "abc123", approve: true`
- **THEN** it loads the halted state and continues pipeline execution

#### Scenario: Resume with deny cancels pipeline

- **WHEN** the Resume action receives `token: "abc123", approve: false`
- **THEN** it deletes the halted state and returns a cancelled envelope

### Requirement: Resume action handles invalid tokens

The action SHALL return a clear error when the token is not found or has expired.

#### Scenario: Invalid token returns error

- **WHEN** the Resume action receives `token: "nonexistent"`
- **THEN** it returns `{:error, "Workflow state not found. Token may have expired."}`

### Requirement: Resume action checks workflow enabled config

The action SHALL check `workflow.enabled` config before proceeding.

#### Scenario: Workflow disabled returns error

- **WHEN** the Resume action is called with `workflow.enabled = false`
- **THEN** it returns `{:error, "Workflow system is disabled"}`

### Requirement: Resume action returns structured Envelope output

The action SHALL return the Runner's Envelope output: `ok` on successful continuation, `cancelled` on deny.

#### Scenario: Approved resume returns ok envelope

- **WHEN** the pipeline completes after resume with approve
- **THEN** the action returns `{:ok, %{"status" => "ok", "result" => ...}}`

#### Scenario: Denied resume returns cancelled envelope

- **WHEN** resume is called with `approve: false`
- **THEN** the action returns `{:ok, %{"status" => "cancelled", "reason" => ...}}`
