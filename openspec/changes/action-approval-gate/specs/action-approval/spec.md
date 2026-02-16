## ADDED Requirements

### Requirement: Configurable action approval list

The system SHALL provide an `[approval]` configuration section that specifies which actions require human approval before execution. The configuration SHALL include an `enabled` flag, a list of action names, a timeout in seconds, and a default behavior on timeout (`"deny"` or `"approve"`).

#### Scenario: Approval enabled with actions listed

- **WHEN** config contains `[approval]` with `enabled = true` and `actions = ["exec", "spawn_subagent"]`
- **THEN** the actions named `exec` and `spawn_subagent` SHALL require human approval before execution, and all other actions SHALL execute normally

#### Scenario: Approval disabled

- **WHEN** config contains `[approval]` with `enabled = false`
- **THEN** all actions SHALL execute normally without any approval check

#### Scenario: Approval enabled with empty action list

- **WHEN** config contains `[approval]` with `enabled = true` and `actions = []`
- **THEN** all actions SHALL execute normally without any approval check

### Requirement: Guarded action wrapper intercepts protected actions

The system SHALL replace protected actions in the agent's tool list with guarded wrapper modules. The wrapper SHALL have the same action name, description, and schema as the original action. The wrapper SHALL check for approval before delegating to the original action's `run/2`.

#### Scenario: Guarded action blocks without approval

- **WHEN** a guarded action's `run/2` is called
- **AND** no valid approval exists for this invocation
- **THEN** the wrapper SHALL request approval from the human operator before proceeding

#### Scenario: Guarded action delegates on approval

- **WHEN** a guarded action receives approval from the human operator
- **THEN** the wrapper SHALL delegate to the original action's `run/2` with the same params and context
- **AND** SHALL return the original action's result unchanged

#### Scenario: Non-protected actions unaffected

- **WHEN** an action is not in the approval list
- **THEN** the action SHALL execute directly without any approval overhead

### Requirement: Approval request and response flow

The system SHALL provide an `Approval.Server` GenServer that manages pending approval requests. A request SHALL block the calling process until the human responds or the timeout expires.

#### Scenario: Approval granted within timeout

- **WHEN** a guarded action requests approval
- **AND** the human responds with "approve" within the configured timeout
- **THEN** the request SHALL return `:approved`
- **AND** the original action SHALL execute

#### Scenario: Approval denied by human

- **WHEN** a guarded action requests approval
- **AND** the human responds with "deny"
- **THEN** the request SHALL return `{:denied, "Denied by operator"}`
- **AND** the original action SHALL NOT execute
- **AND** the action SHALL return `{:error, "Action denied by operator"}`

#### Scenario: Approval times out with default deny

- **WHEN** a guarded action requests approval
- **AND** the human does not respond within the configured timeout
- **AND** the default behavior is `"deny"`
- **THEN** the request SHALL return `{:denied, "Approval timed out"}`
- **AND** the original action SHALL NOT execute

#### Scenario: Approval times out with default approve

- **WHEN** a guarded action requests approval
- **AND** the human does not respond within the configured timeout
- **AND** the default behavior is `"approve"`
- **THEN** the request SHALL return `:approved`
- **AND** the original action SHALL execute

### Requirement: Approval notification via active channel

The system SHALL deliver approval requests to the human operator through the channel that originated the agent session (Telegram or CLI). The notification SHALL include the action name and a summary of key parameters.

#### Scenario: Telegram approval notification

- **WHEN** an approval is requested for an agent running on the Telegram channel
- **THEN** the system SHALL send a Telegram message to the originating chat with the action name, parameter summary, and inline keyboard buttons for Approve and Deny

#### Scenario: CLI approval notification

- **WHEN** an approval is requested for an agent running on the CLI channel
- **THEN** the system SHALL print the action name, parameter summary, and a `[y/n]` prompt to stdout
- **AND** SHALL read the operator's response from stdin

#### Scenario: Approval prompt includes action context

- **WHEN** an approval notification is sent
- **THEN** the notification SHALL include the action name and a human-readable summary of the action's parameters (truncated to a reasonable length)

### Requirement: Telegram callback query handling for approvals

The Telegram channel handler SHALL process `callback_query` updates for approval responses. When the operator taps an Approve or Deny button, the handler SHALL route the response to `Approval.Server`.

#### Scenario: Operator taps Approve button

- **WHEN** the operator taps the Approve inline keyboard button on an approval prompt
- **THEN** the Telegram handler SHALL call `Approval.Server.respond(ref, :approve)`
- **AND** the inline keyboard SHALL be replaced with a confirmation message

#### Scenario: Operator taps Deny button

- **WHEN** the operator taps the Deny inline keyboard button on an approval prompt
- **THEN** the Telegram handler SHALL call `Approval.Server.respond(ref, :deny)`
- **AND** the inline keyboard SHALL be replaced with a denial message

#### Scenario: Stale callback query

- **WHEN** the operator taps an approval button after the request has already been resolved (by timeout or prior response)
- **THEN** the handler SHALL respond with a message indicating the request is no longer active

### Requirement: CLI approval response handling

The CLI channel SHALL detect approval-format responses and route them to `Approval.Server` instead of the agent.

#### Scenario: Operator types y at CLI approval prompt

- **WHEN** the CLI displays an approval prompt
- **AND** the operator types `y` or `yes`
- **THEN** the CLI SHALL call `Approval.Server.respond(ref, :approve)`

#### Scenario: Operator types n at CLI approval prompt

- **WHEN** the CLI displays an approval prompt
- **AND** the operator types `n` or `no`
- **THEN** the CLI SHALL call `Approval.Server.respond(ref, :deny)`

### Requirement: Approval.Server process lifecycle

The `Approval.Server` SHALL be started as part of the application supervision tree. It SHALL handle concurrent approval requests from multiple agents independently.

#### Scenario: Concurrent approvals from different agents

- **WHEN** two agents each request approval simultaneously
- **THEN** each request SHALL be tracked independently with a unique reference
- **AND** approving one SHALL NOT affect the other

#### Scenario: Server restart clears pending requests

- **WHEN** the Approval.Server restarts
- **THEN** all pending approval requests SHALL be considered timed out
- **AND** the calling processes SHALL receive `{:denied, "Approval server restarted"}`
