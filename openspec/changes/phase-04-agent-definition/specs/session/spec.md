## ADDED Requirements

### Requirement: Session skill state initialization
`Goodwizard.Skills.Session` SHALL be a Jido Skill with `state_key: :session` that initializes with an empty messages list, a `created_at` timestamp, and an empty metadata map when mounted.

#### Scenario: Mount initializes session state
- **WHEN** the Session skill is mounted on an agent via `mount/2`
- **THEN** the agent's state at key `:session` contains `%{messages: [], created_at: <iso8601_string>, metadata: %{}}`

### Requirement: Add message to session
The `add_message/4` function SHALL append a message with role, content, and timestamp to the session's messages list.

#### Scenario: Add user message
- **WHEN** `Session.add_message(state, "user", "Hello", timestamp)` is called
- **THEN** the session's messages list contains `%{role: "user", content: "Hello", timestamp: timestamp}` as the last entry

#### Scenario: Add assistant message
- **WHEN** `Session.add_message(state, "assistant", "Hi there", timestamp)` is called
- **THEN** the session's messages list contains `%{role: "assistant", content: "Hi there", timestamp: timestamp}` as the last entry

#### Scenario: Messages preserve insertion order
- **WHEN** three messages are added sequentially
- **THEN** `get_history/2` returns them in the same order they were added

### Requirement: Get conversation history
The `get_history/2` function SHALL return the session's messages list, optionally limited to the most recent N messages.

#### Scenario: Get full history
- **WHEN** `Session.get_history(state)` is called on a session with 5 messages
- **THEN** all 5 messages are returned in order

#### Scenario: Get history with limit
- **WHEN** `Session.get_history(state, limit: 3)` is called on a session with 5 messages
- **THEN** the 3 most recent messages are returned in order

#### Scenario: Get history from empty session
- **WHEN** `Session.get_history(state)` is called on a freshly mounted session
- **THEN** an empty list is returned

### Requirement: Clear session
The `clear/1` function SHALL reset the session's messages list to empty while preserving `created_at` and metadata.

#### Scenario: Clear resets messages only
- **WHEN** `Session.clear(state)` is called on a session with messages
- **THEN** the session's messages list is empty
- **THEN** the session's `created_at` value is unchanged
- **THEN** the session's `metadata` value is unchanged
