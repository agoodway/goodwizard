## ADDED Requirements

### Requirement: Actions convert to tool definitions via ToolAdapter
All Phase 2 Jido Actions SHALL convert to valid ReqLLM tool definitions when passed through `Jido.AI.ToolAdapter.from_actions/1`. Each tool definition MUST include a name, description, and parameter schema matching the action's schema.

#### Scenario: Filesystem actions produce correct tool definitions
- **WHEN** `ToolAdapter.from_actions([Goodwizard.Actions.Filesystem.ReadFile, WriteFile, EditFile, ListDir])` is called
- **THEN** 4 tool definitions are returned, each with a name matching the action name, a non-empty description, and a JSON Schema parameter definition

#### Scenario: Shell action produces correct tool definition
- **WHEN** `ToolAdapter.from_actions([Goodwizard.Actions.Shell.Exec])` is called
- **THEN** 1 tool definition is returned with name, description, and parameter schema including `command` and `timeout` parameters

#### Scenario: Parameter types map correctly
- **WHEN** an action schema defines a `:string` field
- **THEN** the tool definition's parameter schema represents it as `{"type": "string"}`

### Requirement: Executor dispatches tool calls to actions
The `Jido.AI.Executor` SHALL dispatch tool calls by name to the corresponding registered Jido Action, normalizing string keys to atom keys before calling the action's `run/2`.

#### Scenario: Execute tool by name with string keys
- **WHEN** Executor receives a tool call `%{name: "read_file", arguments: %{"path" => "/tmp/test.txt"}}`
- **THEN** it calls `Goodwizard.Actions.Filesystem.ReadFile.run/2` with `%{path: "/tmp/test.txt"}`

#### Scenario: Execute tool returns action result
- **WHEN** Executor dispatches a tool call and the action returns `{:ok, %{output: "content"}}`
- **THEN** Executor returns the action's result to the caller

#### Scenario: Execute tool returns action error
- **WHEN** Executor dispatches a tool call and the action returns `{:error, "file not found"}`
- **THEN** Executor returns the error to the caller without crashing

### Requirement: All five actions are registerable as tools
The full set of Phase 2 actions (ReadFile, WriteFile, EditFile, ListDir, Exec) SHALL be registerable in `Jido.AI.Tools.Registry` without conflicts or errors.

#### Scenario: Register all actions
- **WHEN** all 5 action modules are registered via `Tools.Registry.register_actions/1`
- **THEN** all 5 are retrievable by name from the registry

#### Scenario: No name collisions
- **WHEN** all 5 actions are registered
- **THEN** each action has a unique tool name derived from the module
