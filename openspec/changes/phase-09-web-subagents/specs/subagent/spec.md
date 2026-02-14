## ADDED Requirements

### Requirement: SubAgent module defines a focused background agent
The `Goodwizard.SubAgent` module SHALL use `Jido.AI.ReActAgent` with a limited set of tools: `Goodwizard.Actions.Filesystem.ReadFile`, `Goodwizard.Actions.Filesystem.WriteFile`, `Goodwizard.Actions.Filesystem.ListDir`, and `Goodwizard.Actions.Shell.Exec`. It SHALL NOT include `Goodwizard.Actions.Subagent.Spawn` or `Goodwizard.Actions.Messaging.Send` in its tool list.

#### Scenario: SubAgent has filesystem and shell tools only
- **WHEN** a `SubAgent` is instantiated
- **THEN** its tool list SHALL contain only `ReadFile`, `WriteFile`, `ListDir`, and `Exec`

#### Scenario: SubAgent cannot spawn other subagents
- **WHEN** a `SubAgent` attempts to use a spawn tool
- **THEN** the tool SHALL not be available, preventing recursive agent spawning

#### Scenario: SubAgent uses configured model
- **WHEN** a `SubAgent` is instantiated
- **THEN** it SHALL use the model from `Goodwizard.Config.get("agent.model")` with a fallback to `"anthropic:claude-sonnet-4-5"`

#### Scenario: SubAgent has iteration limit
- **WHEN** a `SubAgent` is running and reaches 10 iterations
- **THEN** it SHALL stop and return its current results

### Requirement: Subagent.Spawn action starts a background subagent
The `Goodwizard.Actions.Subagent.Spawn` action SHALL use `use Jido.Action` with a schema accepting `task` (required, string) and `context` (optional, string). The `run/2` callback SHALL start a `Goodwizard.SubAgent` as an Elixir Task to execute the given task.

#### Scenario: Spawn a subagent with a task
- **WHEN** `Subagent.Spawn` is called with `task: "Read the file at ~/notes.md and summarize it"`
- **THEN** it SHALL start a `SubAgent` as a linked Task, pass the task as the agent prompt, and return `{:ok, %{message: "Subagent spawned for task: <task>", task_ref: <reference>}}`

#### Scenario: Spawn with context
- **WHEN** `Subagent.Spawn` is called with `task: "Analyze this code"` and `context: "The project uses Phoenix 1.8"`
- **THEN** it SHALL prepend the context to the task prompt sent to the SubAgent

#### Scenario: Subagent completes successfully
- **WHEN** a spawned SubAgent finishes its task
- **THEN** it SHALL emit a signal `{:subagent_complete, task_ref, result}` back to the parent agent

#### Scenario: Subagent fails
- **WHEN** a spawned SubAgent encounters an unrecoverable error
- **THEN** it SHALL emit a signal `{:subagent_error, task_ref, reason}` back to the parent agent

#### Scenario: Subagent times out
- **WHEN** a spawned SubAgent exceeds its maximum iterations (10) without completing
- **THEN** it SHALL return whatever partial results it has accumulated
