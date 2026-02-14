## ADDED Requirements

### Requirement: Agent module uses ReActAgent macro
The `Goodwizard.Agent` module SHALL use `Jido.AI.ReActAgent` with the following configuration:
- `name: "goodwizard"`
- `description: "Personal AI assistant"`
- `tools:` list containing all five Phase 2 actions (ReadFile, WriteFile, EditFile, ListDir, Exec)
- `model: "anthropic:claude-sonnet-4-5"`
- `max_iterations: 20`

#### Scenario: Module compiles with ReActAgent macro
- **WHEN** `Goodwizard.Agent` is compiled
- **THEN** it defines `ask/2`, `ask/3`, `await/1`, `await/2`, `ask_sync/2`, and `ask_sync/3` functions

#### Scenario: Agent registers all tools
- **WHEN** `Goodwizard.Agent` is started
- **THEN** the agent's tool registry contains entries for `read_file`, `write_file`, `edit_file`, `list_dir`, and `exec`

### Requirement: Agent starts via Jido instance
The agent SHALL be startable via `Goodwizard.Jido.start_agent/2` with an ID and initial state containing `:workspace`, `:channel`, and `:chat_id`.

#### Scenario: Start agent with workspace state
- **WHEN** `Goodwizard.Jido.start_agent(Goodwizard.Agent, id: "cli:direct", initial_state: %{workspace: "/tmp", channel: "cli", chat_id: "direct"})` is called
- **THEN** it returns `{:ok, pid}` where pid is a running process
- **THEN** the agent's state contains the workspace, channel, and chat_id values

### Requirement: Dynamic system prompt via on_before_cmd
The agent SHALL override `on_before_cmd/2` to build a dynamic system prompt using `Goodwizard.ContextBuilder.build_system_prompt/2` before each ReAct cycle.

#### Scenario: System prompt includes workspace bootstrap files
- **WHEN** the agent processes a query and the workspace contains an `AGENTS.md` file
- **THEN** the system prompt passed to the LLM includes the contents of `AGENTS.md`

#### Scenario: System prompt built fresh each turn
- **WHEN** a bootstrap file is modified between two consecutive queries
- **THEN** the second query's system prompt reflects the updated file contents

### Requirement: Session updated via on_after_cmd
The agent SHALL override `on_after_cmd/3` to append the user query and assistant response to the session history after each completed ReAct cycle.

#### Scenario: Session records conversation turn
- **WHEN** the agent completes processing a query
- **THEN** the session history contains a user message with the query text and an assistant message with the response text

### Requirement: Agent handles ask_sync with tool execution
The agent SHALL process queries that require tool calls, executing tools via the ReAct loop and returning a final text response.

#### Scenario: Query triggers tool call
- **WHEN** `ask_sync(pid, "Read the file at /tmp/test.txt")` is called and the LLM responds with a `read_file` tool call
- **THEN** the agent executes the `read_file` action with the specified path
- **THEN** the agent returns `{:ok, response}` where response contains the tool's output integrated into the answer

#### Scenario: Query without tool calls
- **WHEN** `ask_sync(pid, "Hello")` is called and the LLM responds with text only
- **THEN** the agent returns `{:ok, response}` containing the LLM's text response
