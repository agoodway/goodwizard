## ADDED Requirements

### Requirement: LoadMemoryContext action loads relevant episodic memories

The `LoadMemoryContext` action SHALL load recent and topic-relevant episodic memories from the episodic memory store and include them in the returned context.

#### Scenario: Recent episodes loaded without topic

- **WHEN** `LoadMemoryContext` is called with an empty `topic`
- **THEN** it SHALL load the 3 most recent episodes from `memory/episodic/`
- **AND** the returned `memory_context` SHALL include those episodes formatted under a "Relevant Past Experiences" section

#### Scenario: Topic-relevant episodes loaded with topic

- **WHEN** `LoadMemoryContext` is called with a non-empty `topic`
- **THEN** it SHALL load the 3 most recent episodes
- **AND** it SHALL search for additional topic-relevant episodes via text search
- **AND** the two sets SHALL be merged and deduplicated by episode ID
- **AND** the total episodes SHALL NOT exceed `max_episodes`

#### Scenario: No episodes in store

- **WHEN** `LoadMemoryContext` is called and the episodic store is empty
- **THEN** the returned `memory_context` SHALL NOT include a "Relevant Past Experiences" section
- **AND** the action SHALL succeed with `episodes_loaded: 0`

---

### Requirement: LoadMemoryContext action loads relevant procedural memories

The `LoadMemoryContext` action SHALL load relevant procedural memories from the procedural memory store and include them in the returned context.

#### Scenario: Procedures loaded via recall with topic

- **WHEN** `LoadMemoryContext` is called with a non-empty `topic`
- **THEN** it SHALL load procedures via `Memory.Procedural.recall/3` scored by relevance to the topic
- **AND** the total procedures SHALL NOT exceed `max_procedures`
- **AND** the returned `memory_context` SHALL include those procedures formatted under a "Relevant Procedures" section

#### Scenario: Procedures loaded via list without topic

- **WHEN** `LoadMemoryContext` is called with an empty `topic`
- **THEN** it SHALL load procedures via `Memory.Procedural.list/2` ordered by confidence and usage
- **AND** the total procedures SHALL NOT exceed `max_procedures`

#### Scenario: No procedures in store

- **WHEN** `LoadMemoryContext` is called and the procedural store is empty
- **THEN** the returned `memory_context` SHALL NOT include a "Relevant Procedures" section
- **AND** the action SHALL succeed with `procedures_loaded: 0`

---

### Requirement: Memory context is formatted as readable markdown

The `LoadMemoryContext` action SHALL format loaded memories as compact, readable markdown suitable for inclusion in the system prompt.

#### Scenario: Episode formatting

- **WHEN** episodes are included in the memory context
- **THEN** each episode SHALL be rendered with its timestamp, type, outcome, and summary
- **AND** each episode SHALL include the key lesson from its body (if present)

#### Scenario: Procedure formatting

- **WHEN** procedures are included in the memory context
- **THEN** each procedure SHALL be rendered with its summary, confidence level, and when-to-apply trigger conditions

#### Scenario: Both stores have content

- **WHEN** both episodes and procedures are loaded
- **THEN** the context SHALL contain both "Relevant Past Experiences" and "Relevant Procedures" sections

#### Scenario: Both stores are empty

- **WHEN** both the episodic and procedural stores are empty
- **THEN** the returned `memory_context` SHALL be an empty string

---

### Requirement: Channel handlers load memory context on first message

Channel handlers (CLI and Telegram) SHALL call `LoadMemoryContext` on the first message of a new session and inject the result into the system prompt.

#### Scenario: CLI loads memory context on session start

- **WHEN** a new CLI session starts and the user sends the first message
- **THEN** the CLI handler SHALL call `LoadMemoryContext` with the first message text as `topic`
- **AND** the returned `memory_context` SHALL be appended to the system prompt

#### Scenario: Telegram loads memory context on session start

- **WHEN** a new Telegram session starts and the user sends the first message
- **THEN** the Telegram handler SHALL call `LoadMemoryContext` with the first message text as `topic`
- **AND** the returned `memory_context` SHALL be appended to the system prompt

#### Scenario: Memory loading failure does not block conversation

- **WHEN** `LoadMemoryContext` fails for any reason (file errors, empty stores, action errors)
- **THEN** the channel handler SHALL log a debug-level warning
- **AND** the conversation SHALL proceed normally without memory context
- **AND** no error SHALL be displayed to the user

---

### Requirement: LoadMemoryContext returns structured result

The `LoadMemoryContext` action SHALL return a result map with the formatted context and loading statistics.

#### Scenario: Successful context load

- **WHEN** `LoadMemoryContext` completes successfully
- **THEN** the result SHALL include `memory_context` (formatted string), `episodes_loaded` (integer), and `procedures_loaded` (integer)

#### Scenario: Partial context load

- **WHEN** episodes are loaded but the procedural store is empty
- **THEN** the result SHALL include `episodes_loaded` with the count and `procedures_loaded: 0`
- **AND** `memory_context` SHALL contain only the episodes section
