## ADDED Requirements

### Requirement: System prompt includes identity section
The `Goodwizard.ContextBuilder.build_system_prompt/2` function SHALL produce a system prompt that begins with an identity section containing the agent name, current UTC timestamp, Elixir runtime version, and the absolute workspace path.

#### Scenario: Identity section present with all fields
- **WHEN** `build_system_prompt(workspace, [])` is called with a valid workspace path
- **THEN** the returned string starts with an identity section containing name, timestamp, runtime version, and workspace path

#### Scenario: Workspace path is absolute
- **WHEN** `build_system_prompt("/home/user/project", [])` is called
- **THEN** the identity section includes `"/home/user/project"` as the workspace path

### Requirement: System prompt loads bootstrap files from workspace
The `build_system_prompt/2` function SHALL read bootstrap files (`AGENTS.md`, `SOUL.md`, `USER.md`, `TOOLS.md`, `IDENTITY.md`) from the workspace directory and include their contents as separate sections in the system prompt. Missing files SHALL be silently skipped.

#### Scenario: All bootstrap files present
- **WHEN** the workspace contains all 5 bootstrap files
- **THEN** the system prompt includes the content of each file as a separate section

#### Scenario: Some bootstrap files missing
- **WHEN** the workspace contains only `SOUL.md` and `TOOLS.md`
- **THEN** the system prompt includes only those two files' content and does not error

#### Scenario: No bootstrap files present
- **WHEN** the workspace contains none of the bootstrap files
- **THEN** the system prompt contains only the identity section without error

### Requirement: System prompt includes memory context
The `build_system_prompt/2` function SHALL include memory context in the system prompt when provided via the `:memory` option.

#### Scenario: Memory context provided
- **WHEN** `build_system_prompt(workspace, memory: "Previous conversation summary...")` is called
- **THEN** the system prompt includes the memory content as a section

#### Scenario: No memory context
- **WHEN** `build_system_prompt(workspace, [])` is called without memory option
- **THEN** the system prompt does not include a memory section

### Requirement: System prompt includes skills summary
The `build_system_prompt/2` function SHALL include a skills summary section when provided via the `:skills` option.

#### Scenario: Skills summary provided
- **WHEN** `build_system_prompt(workspace, skills: "Available skills: search, edit, run")` is called
- **THEN** the system prompt includes the skills summary as a section

### Requirement: Prompt sections joined with separators
The `build_system_prompt/2` function SHALL join all prompt sections with `"\n\n---\n\n"` separators.

#### Scenario: Multiple sections separated correctly
- **WHEN** a system prompt is built with identity, bootstrap files, and memory
- **THEN** each section is separated by `"\n\n---\n\n"`

### Requirement: Build complete message list
The `Goodwizard.ContextBuilder.build_messages/1` function SHALL construct a message list in the format `[system_message, ...history_messages, user_message]` compatible with `Jido.AI.Conversation`.

#### Scenario: Messages with history
- **WHEN** `build_messages(system: system_prompt, history: [msg1, msg2], user: "Hello")` is called
- **THEN** the result is a list starting with a system role message, followed by history messages, ending with a user role message

#### Scenario: Messages without history
- **WHEN** `build_messages(system: system_prompt, history: [], user: "Hello")` is called
- **THEN** the result is `[system_message, user_message]`

### Requirement: Add tool result to message list
The `Goodwizard.ContextBuilder.add_tool_result/4` function SHALL append a tool result message to an existing message list in the format expected by `Jido.AI.Conversation`.

#### Scenario: Tool result appended
- **WHEN** `add_tool_result(messages, "call_123", "read_file", "file contents here")` is called
- **THEN** a tool result message is appended with the correct tool_call_id, tool name, and content

### Requirement: Add assistant message to message list
The `Goodwizard.ContextBuilder.add_assistant_message/3` function SHALL append an assistant message to an existing message list, optionally including tool calls.

#### Scenario: Plain assistant message
- **WHEN** `add_assistant_message(messages, "I'll read that file for you.")` is called
- **THEN** an assistant role message with the given content is appended

#### Scenario: Assistant message with tool calls
- **WHEN** `add_assistant_message(messages, "Reading file...", tool_calls: [tool_call])` is called
- **THEN** an assistant role message with content and tool_calls is appended
