## ADDED Requirements

### Requirement: ReadLongTerm reads MEMORY.md content
The `Goodwizard.Actions.Memory.ReadLongTerm` action SHALL return the current contents of MEMORY.md from the agent's memory skill state.

#### Scenario: Read existing long-term memory
- **WHEN** `ReadLongTerm` is run and MEMORY.md contains "Project uses Phoenix 1.8"
- **THEN** it returns `{:ok, %{content: "Project uses Phoenix 1.8"}}`

#### Scenario: Read empty long-term memory
- **WHEN** `ReadLongTerm` is run and MEMORY.md does not exist or is empty
- **THEN** it returns `{:ok, %{content: ""}}`

### Requirement: WriteLongTerm writes MEMORY.md content
The `Goodwizard.Actions.Memory.WriteLongTerm` action SHALL write the provided content to MEMORY.md in the memory directory and update the skill state's `long_term_content`.

#### Scenario: Write new content to MEMORY.md
- **WHEN** `WriteLongTerm` is run with `%{content: "Updated memory notes"}`
- **THEN** MEMORY.md in the memory directory contains "Updated memory notes"
- **THEN** the skill state's `long_term_content` is updated to "Updated memory notes"

#### Scenario: Overwrite existing MEMORY.md
- **WHEN** MEMORY.md already contains "Old content" and `WriteLongTerm` is run with `%{content: "New content"}`
- **THEN** MEMORY.md contains only "New content"

#### Scenario: Write creates MEMORY.md if missing
- **WHEN** MEMORY.md does not exist and `WriteLongTerm` is run with content
- **THEN** MEMORY.md is created with the provided content

### Requirement: AppendHistory appends timestamped entry to HISTORY.md
The `Goodwizard.Actions.Memory.AppendHistory` action SHALL append a timestamped line to HISTORY.md in the memory directory.

#### Scenario: Append entry to existing HISTORY.md
- **WHEN** `AppendHistory` is run with `%{entry: "Discussed deployment strategy"}`
- **THEN** HISTORY.md contains a new line formatted as `[<ISO8601_timestamp>] Discussed deployment strategy`

#### Scenario: Append creates HISTORY.md if missing
- **WHEN** HISTORY.md does not exist and `AppendHistory` is run with an entry
- **THEN** HISTORY.md is created with the timestamped entry as its first line

#### Scenario: Multiple appends preserve order
- **WHEN** three entries are appended sequentially
- **THEN** HISTORY.md contains all three lines in the order they were appended

### Requirement: SearchHistory searches HISTORY.md by pattern
The `Goodwizard.Actions.Memory.SearchHistory` action SHALL search HISTORY.md for lines matching a given pattern and return matching lines.

#### Scenario: Pattern matches multiple lines
- **WHEN** HISTORY.md contains 10 lines and `SearchHistory` is run with `%{pattern: "deployment"}`
- **THEN** it returns `{:ok, %{matches: [<lines_containing_deployment>]}}`

#### Scenario: Pattern matches no lines
- **WHEN** `SearchHistory` is run with a pattern that matches nothing
- **THEN** it returns `{:ok, %{matches: []}}`

#### Scenario: Search on missing HISTORY.md
- **WHEN** HISTORY.md does not exist and `SearchHistory` is run
- **THEN** it returns `{:ok, %{matches: []}}`

#### Scenario: Search is case-insensitive
- **WHEN** HISTORY.md contains "Discussed Deployment" and pattern is "deployment"
- **THEN** the matching line is included in results

### Requirement: Consolidate performs LLM-driven memory consolidation
The `Goodwizard.Actions.Memory.Consolidate` action SHALL take old messages from the session, call the LLM to produce a history entry and optional memory update, then update HISTORY.md and MEMORY.md accordingly, and trim the session to the most recent N messages.

#### Scenario: Consolidation with memory update
- **WHEN** `Consolidate` is run with session messages exceeding the memory window
- **THEN** old messages (all except the most recent N) are formatted as timestamped lines
- **THEN** the LLM is called with a consolidation prompt and returns JSON with `history_entry` and `memory_update`
- **THEN** `history_entry` is appended to HISTORY.md
- **THEN** MEMORY.md is updated with `memory_update` content
- **THEN** the session is trimmed to the most recent N messages

#### Scenario: Consolidation without memory update
- **WHEN** the LLM's consolidation response has `memory_update` as null or empty
- **THEN** HISTORY.md is still updated with the `history_entry`
- **THEN** MEMORY.md is not modified

#### Scenario: Consolidation prompt format
- **WHEN** `Consolidate` formats old messages for the LLM
- **THEN** each message is formatted as `[<timestamp>] <role>: <content>`
- **THEN** the prompt includes the current MEMORY.md content for context
- **THEN** the prompt requests JSON output with `history_entry` (string) and `memory_update` (string or null)

#### Scenario: Session trimming preserves recent messages
- **WHEN** the session has 60 messages and `memory_window` is 50
- **THEN** after consolidation the session contains the 50 most recent messages
