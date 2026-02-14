## MODIFIED Requirements

### Requirement: Dynamic system prompt via on_before_cmd
The agent SHALL override `on_before_cmd/2` to build a dynamic system prompt using `Goodwizard.ContextBuilder.build_system_prompt/2` before each ReAct cycle. The system prompt SHALL include memory content from the Memory skill's `long_term_content` state via the `:memory` option. Before building the prompt, `on_before_cmd/2` SHALL check if the session message count exceeds `memory_window` and trigger consolidation if so.

#### Scenario: System prompt includes workspace bootstrap files
- **WHEN** the agent processes a query and the workspace contains an `AGENTS.md` file
- **THEN** the system prompt passed to the LLM includes the contents of `AGENTS.md`

#### Scenario: System prompt built fresh each turn
- **WHEN** a bootstrap file is modified between two consecutive queries
- **THEN** the second query's system prompt reflects the updated file contents

#### Scenario: System prompt includes long-term memory
- **WHEN** the agent processes a query and MEMORY.md contains "User prefers TypeScript"
- **THEN** the system prompt includes "User prefers TypeScript" in the memory section

#### Scenario: Consolidation triggered before prompt build
- **WHEN** the session has more messages than `memory_window` (default 50)
- **THEN** `on_before_cmd/2` runs the Consolidate action before building the system prompt
- **THEN** the system prompt reflects the updated memory content after consolidation

#### Scenario: No consolidation when under memory window
- **WHEN** the session has fewer messages than `memory_window`
- **THEN** `on_before_cmd/2` skips consolidation and proceeds directly to building the system prompt

### Requirement: Session updated via on_after_cmd
The agent SHALL override `on_after_cmd/3` to append the user query and assistant response to the session history after each completed ReAct cycle. After updating the session, it SHALL persist the session to JSONL.

#### Scenario: Session records conversation turn
- **WHEN** the agent completes processing a query
- **THEN** the session history contains a user message with the query text and an assistant message with the response text

#### Scenario: Session persisted after each turn
- **WHEN** `on_after_cmd/3` completes
- **THEN** the session is saved to the JSONL file in `~/.goodwizard/sessions/`

## ADDED Requirements

### Requirement: Memory actions registered as additional tools
The agent SHALL register the five memory actions (ReadLongTerm, WriteLongTerm, AppendHistory, SearchHistory, Consolidate) as tools available to the LLM alongside the existing Phase 2 tools.

#### Scenario: Memory tools available in agent
- **WHEN** `Goodwizard.Agent` is started
- **THEN** the agent's tool registry contains entries for `read_long_term`, `write_long_term`, `append_history`, `search_history`, and `consolidate`

#### Scenario: LLM can call memory tools
- **WHEN** the LLM responds with a `read_long_term` tool call
- **THEN** the agent executes the `ReadLongTerm` action and returns the result

### Requirement: Memory skill mounted on agent
The agent SHALL mount `Goodwizard.Skills.Memory` as an additional skill, initializing memory state from the workspace's MEMORY.md when the agent starts.

#### Scenario: Agent starts with memory loaded
- **WHEN** `Goodwizard.Jido.start_agent(Goodwizard.Agent, ...)` is called with a workspace containing MEMORY.md
- **THEN** the agent's state at `:memory` contains the loaded MEMORY.md content

#### Scenario: Agent starts without MEMORY.md
- **WHEN** the workspace has no MEMORY.md
- **THEN** the agent starts successfully with empty `long_term_content` in memory state
