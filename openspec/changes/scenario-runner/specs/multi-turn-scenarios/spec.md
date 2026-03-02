### Requirement: Sequential query steps

The system SHALL send multiple queries to the same agent in sequence, preserving session state between turns.

#### Scenario: Memory continuity across turns
- **WHEN** a scenario has step 1 `"My name is Tom"` and step 2 `"What is my name?"`
- **THEN** step 2 SHALL have access to the session context from step 1 (the agent remembers the name)

### Requirement: Setup steps between queries

The system SHALL support workspace mutation steps interleaved with query steps.

#### Scenario: Write file before query
- **WHEN** a step has `type = "setup"`, `action = "write_file"`, `path = "notes.md"`, and `content = "..."`
- **THEN** the system SHALL create the file in the workspace before executing the next step

#### Scenario: Delete file before query
- **WHEN** a step has `type = "setup"`, `action = "delete_file"`, and `path = "old.md"`
- **THEN** the system SHALL delete the file from the workspace before executing the next step

### Requirement: Conversation replay

The system SHALL replay conversations from session JSONL files to reproduce bugs.

#### Scenario: Replay from session file
- **WHEN** a scenario has a `[replay]` section with `session_file` pointing to a valid JSONL session
- **THEN** the system SHALL load the session messages, pre-seed the agent's session state, and send the final user message as a live query

#### Scenario: Replay with message limit
- **WHEN** `up_to_message` is specified in the `[replay]` section
- **THEN** the system SHALL only load messages up to that index
