## ADDED Requirements

### Requirement: Task-list parsing
The system SHALL parse HEARTBEAT.md lines matching `- [ ] <text>` or `- [x] <text>` as individual check items. Each matched line produces one check with its text content extracted (without the checkbox prefix).

#### Scenario: File has multiple task-list items
- **GIVEN** a HEARTBEAT.md file containing:
  ```
  - [ ] Check inbox for new messages
  - [ ] Review calendar for events in the next 2 hours
  - [ ] Run project health check on goodwizard
  ```
- **WHEN** the heartbeat parser processes the file
- **THEN** it SHALL return 3 check items: `["Check inbox for new messages", "Review calendar for events in the next 2 hours", "Run project health check on goodwizard"]`

#### Scenario: File has no task-list items
- **GIVEN** a HEARTBEAT.md file containing only plain text (no lines matching `- [ ] ` or `- [x] `)
- **WHEN** the heartbeat parser processes the file
- **THEN** it SHALL indicate plain text mode and return no check items

#### Scenario: File has mixed task-list and prose lines
- **GIVEN** a HEARTBEAT.md file containing both task-list lines and plain prose lines
- **WHEN** the heartbeat parser processes the file
- **THEN** it SHALL extract only the task-list lines as check items (prose lines are excluded)

#### Scenario: Checked items are parsed the same as unchecked
- **GIVEN** a HEARTBEAT.md file containing `- [x] Already done` and `- [ ] Still pending`
- **WHEN** the heartbeat parser processes the file
- **THEN** both lines SHALL be parsed as check items with text `"Already done"` and `"Still pending"`

### Requirement: Structured prompt generation
When check items are parsed, the system SHALL generate a structured prompt wrapping the items in a numbered instruction format with a preamble.

#### Scenario: Multiple checks produce numbered prompt
- **GIVEN** 3 parsed check items: `["Check inbox", "Review calendar", "Run health check"]`
- **WHEN** the structured prompt is generated
- **THEN** the prompt SHALL be:
  ```
  Process each of the following awareness checks and report on each:
  1. Check inbox
  2. Review calendar
  3. Run health check
  ```

#### Scenario: Single check produces numbered prompt
- **GIVEN** 1 parsed check item: `["Check inbox"]`
- **WHEN** the structured prompt is generated
- **THEN** the prompt SHALL be:
  ```
  Process each of the following awareness checks and report on each:
  1. Check inbox
  ```

### Requirement: Checks metadata in message payload
When dispatching a structured heartbeat, the system SHALL include a `checks` field in the Messaging payload metadata containing the parsed check items with their index and text.

#### Scenario: Structured heartbeat includes checks metadata
- **GIVEN** 3 parsed check items dispatched as a heartbeat
- **WHEN** the user message is saved to the Messaging room
- **THEN** the message metadata SHALL include `checks: [%{index: 1, text: "Check inbox"}, %{index: 2, text: "Review calendar"}, %{index: 3, text: "Run health check"}]`

#### Scenario: Plain text heartbeat has no checks metadata
- **GIVEN** a plain text HEARTBEAT.md dispatched as a heartbeat
- **WHEN** the user message is saved to the Messaging room
- **THEN** the message metadata SHALL NOT include a `checks` field

### Requirement: Backwards compatibility with plain text
When HEARTBEAT.md contains no task-list syntax, the system SHALL dispatch the file contents as a single blob message, identical to the current behavior.

#### Scenario: Plain text file dispatches as single message
- **GIVEN** a HEARTBEAT.md file with plain prose content: `"Check on all active projects and summarize status"`
- **WHEN** the heartbeat processes the file
- **THEN** the content SHALL be sent to the agent as-is without modification
- **AND** no `checks` metadata SHALL be included in the message

#### Scenario: Empty file is still skipped
- **GIVEN** a HEARTBEAT.md file that is empty or whitespace-only
- **WHEN** the heartbeat processes the file
- **THEN** the system SHALL skip processing (existing behavior preserved)
