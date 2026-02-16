## ADDED Requirements

### Requirement: Add a check to heartbeat
The `update_heartbeat_checks` action with `operation: "add"` SHALL append a new `- [ ] <text>` line to HEARTBEAT.md. If the file does not exist, it SHALL be created.

#### Scenario: Add check to existing file
- **WHEN** the action is called with `operation: "add"` and `text: "Check inbox for new messages"`
- **THEN** the line `- [ ] Check inbox for new messages` SHALL be appended to HEARTBEAT.md
- **AND** existing checks SHALL be preserved

#### Scenario: Add check to empty or missing file
- **WHEN** the action is called with `operation: "add"` and HEARTBEAT.md does not exist or is empty
- **THEN** the file SHALL be created with a single line `- [ ] <text>`

#### Scenario: Duplicate check text
- **WHEN** the action is called with `operation: "add"` and a check with identical text already exists
- **THEN** the action SHALL return an error indicating the check already exists

### Requirement: Remove a check from heartbeat
The `update_heartbeat_checks` action with `operation: "remove"` SHALL remove the check line matching the given text from HEARTBEAT.md.

#### Scenario: Remove existing check
- **WHEN** the action is called with `operation: "remove"` and `text: "Check inbox for new messages"`
- **THEN** the line matching that text SHALL be removed from HEARTBEAT.md
- **AND** remaining checks SHALL be preserved

#### Scenario: Remove nonexistent check
- **WHEN** the action is called with `operation: "remove"` and no check matches the given text
- **THEN** the action SHALL return an error indicating the check was not found

### Requirement: List current heartbeat checks
The `update_heartbeat_checks` action with `operation: "list"` SHALL return all current checks from HEARTBEAT.md.

#### Scenario: List checks from structured file
- **WHEN** the action is called with `operation: "list"` and HEARTBEAT.md contains 3 task-list items
- **THEN** the action SHALL return a list of 3 check items with their text

#### Scenario: List checks from empty or missing file
- **WHEN** the action is called with `operation: "list"` and HEARTBEAT.md does not exist or is empty
- **THEN** the action SHALL return an empty list

### Requirement: Action registration
The `update_heartbeat_checks` action SHALL be registered in the `Goodwizard.Agent` tools list.

#### Scenario: Agent starts with heartbeat action
- **WHEN** the agent starts
- **THEN** `update_heartbeat_checks` SHALL be available as a tool
