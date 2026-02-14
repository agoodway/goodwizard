## ADDED Requirements

### Requirement: CLI Server is a GenServer
The `Goodwizard.Channels.CLI.Server` SHALL be a GenServer that manages the CLI REPL lifecycle.

#### Scenario: CLI Server starts successfully
- **WHEN** `Goodwizard.Channels.CLI.Server` is started with `workspace: "/tmp/workspace"` option
- **THEN** it returns `{:ok, pid}` where pid is a running GenServer process

### Requirement: CLI Server creates a Messaging room on init
The CLI Server SHALL create a Messaging room via `Goodwizard.Messaging.get_or_create_room_by_external_binding(:cli, "goodwizard", "direct")` during `init/1` for conversation tracking and message persistence.

#### Scenario: Room created on first start
- **WHEN** the CLI Server initializes for the first time
- **THEN** a Messaging room is created with external binding `{:cli, "goodwizard", "direct"}`
- **THEN** the room_id is stored in the GenServer state

#### Scenario: Room reused on restart
- **WHEN** the CLI Server restarts after a crash
- **THEN** the existing Messaging room is returned (idempotent)

### Requirement: CLI Server starts an AgentServer on init
The CLI Server SHALL start an AgentServer via `Goodwizard.Jido.start_agent/2` during `init/1` with the id `"cli:direct"` and workspace from options.

#### Scenario: Agent started with correct configuration
- **WHEN** the CLI Server initializes with workspace `"/home/user/.goodwizard/workspace"`
- **THEN** an AgentServer is started with id `"cli:direct"`
- **THEN** the agent's initial state contains workspace `"/home/user/.goodwizard/workspace"`, channel `"cli"`, and chat_id `"direct"`

### Requirement: CLI Server runs REPL loop in linked Task
The CLI Server SHALL spawn a linked Task during `init/1` that runs the blocking REPL loop using `IO.gets/1`.

#### Scenario: REPL prompts for input
- **WHEN** the CLI Server initializes and the REPL Task starts
- **THEN** the terminal displays the prompt `"you> "`
- **THEN** the process blocks waiting for user input

#### Scenario: REPL Task crash terminates CLI Server
- **WHEN** the REPL Task process crashes
- **THEN** the CLI Server GenServer terminates

### Requirement: CLI Server saves messages via Messaging API
The CLI Server SHALL save both user input and assistant responses to the Messaging room for conversation persistence.

#### Scenario: User message saved before dispatch
- **WHEN** the user enters `"Hello"` at the REPL prompt
- **THEN** the CLI Server calls `Goodwizard.Messaging.save_message(%{room_id: room_id, sender_id: "user", content: "Hello"})` before dispatching to the agent

#### Scenario: Assistant message saved after response
- **WHEN** the agent returns a response
- **THEN** the CLI Server calls `Goodwizard.Messaging.save_message(%{room_id: room_id, sender_id: "assistant", content: response})` before printing

### Requirement: CLI Server dispatches input to agent
The CLI Server SHALL send user input to the agent via `Goodwizard.Agent.ask_sync/3` with a 120-second timeout and print the response.

#### Scenario: Successful query and response
- **WHEN** the user enters `"Hello"` at the REPL prompt
- **THEN** the CLI Server saves the user message to the room, calls `ask_sync(agent_pid, "Hello", timeout: 120_000)`, saves the assistant response, and prints it as `"\ngoodwizard> <response>\n"`
- **THEN** a new `"you> "` prompt is displayed

#### Scenario: Agent returns error
- **WHEN** the user enters a query and `ask_sync` returns `{:error, reason}`
- **THEN** the error is printed to the terminal
- **THEN** a new `"you> "` prompt is displayed

### Requirement: CLI Server handles EOF gracefully
The CLI Server SHALL terminate cleanly when stdin reaches EOF (`:eof` from `IO.gets/1`).

#### Scenario: EOF exits the REPL
- **WHEN** `IO.gets/1` returns `:eof`
- **THEN** the REPL loop exits
- **THEN** the CLI Server terminates with reason `:normal`
