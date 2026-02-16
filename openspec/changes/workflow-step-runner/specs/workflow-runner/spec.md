## ADDED Requirements

### Requirement: Pipeline steps execute sequentially with stdout piping

The `Goodwizard.Workflow.Runner` module SHALL execute steps in order, passing the stdout of each step as stdin to the next.

#### Scenario: Two-step pipeline pipes stdout

- **WHEN** a pipeline with steps `echo "hello"` and `tr a-z A-Z` is executed
- **THEN** the second step receives `"hello\n"` as stdin and produces `"HELLO\n"`

#### Scenario: Single-step pipeline executes and returns output

- **WHEN** a pipeline with one `exec` step `echo "test"` is executed
- **THEN** the result contains the step's stdout `"test\n"`

#### Scenario: First step receives no stdin

- **WHEN** the first step in a pipeline is executed
- **THEN** it receives no stdin input

### Requirement: Shell commands execute via System.cmd without shell injection

The runner SHALL execute shell commands by splitting them into `[executable | args]` and using `System.cmd/3`. Commands SHALL NOT be passed through `sh -c`.

#### Scenario: Command with arguments executes correctly

- **WHEN** a step has command `"echo hello world"`
- **THEN** it is executed as `System.cmd("echo", ["hello", "world"])` and returns `"hello world\n"`

#### Scenario: Shell metacharacters are not interpreted

- **WHEN** a step has command `"echo $HOME"`
- **THEN** the literal string `$HOME` is printed, not the environment variable value

### Requirement: Approval steps halt execution and return needs_approval envelope

When the runner encounters a step with type `:approve`, it SHALL halt execution, serialize halted state via `Workflow.State`, and return a `needs_approval` envelope.

#### Scenario: Approval step halts pipeline

- **WHEN** a pipeline has steps [exec, approve, exec] and the approve step is reached
- **THEN** the runner returns a `needs_approval` envelope with the approval prompt and a resume token

#### Scenario: Completed step outputs are preserved in halted state

- **WHEN** two exec steps complete before an approval step
- **THEN** both steps' outputs are included in the persisted state

### Requirement: Halted pipelines can be resumed or cancelled

The runner SHALL provide a `resume/2` function accepting a token and decision (`:approve` or `:deny`).

#### Scenario: Resume with approve continues execution

- **WHEN** `resume(token, :approve)` is called with a valid token
- **THEN** execution continues from the step after the approval gate and returns an `ok` envelope

#### Scenario: Resume with deny cancels pipeline

- **WHEN** `resume(token, :deny)` is called
- **THEN** persisted state is deleted and a `cancelled` envelope is returned

#### Scenario: Resume with invalid token returns error

- **WHEN** `resume("nonexistent", :approve)` is called
- **THEN** it returns `{:error, :state_not_found}`

### Requirement: Step conditions control execution

Steps with a `condition` field SHALL be evaluated against accumulated step outputs. Steps whose condition evaluates to false SHALL be skipped.

#### Scenario: True condition executes step

- **WHEN** a step has condition `$steps.lint.exit_code == 0` and lint exited with code 0
- **THEN** the step executes normally

#### Scenario: False condition skips step

- **WHEN** a step has condition `$steps.lint.exit_code == 0` and lint exited with code 1
- **THEN** the step is skipped and execution continues to the next step

### Requirement: Pipeline timeout is enforced

The runner SHALL enforce a pipeline-level `timeout_ms`. If the pipeline does not complete within the timeout, execution is killed.

#### Scenario: Pipeline completes within timeout

- **WHEN** a pipeline completes in 100ms with a 20000ms timeout
- **THEN** the result is returned normally

#### Scenario: Pipeline exceeds timeout

- **WHEN** a pipeline takes longer than `timeout_ms`
- **THEN** execution is killed and an error result is returned

### Requirement: Per-step output cap is enforced

The runner SHALL check each step's stdout against `max_stdout_bytes`. Output exceeding the cap SHALL be truncated.

#### Scenario: Output within cap is preserved

- **WHEN** a step produces 1000 bytes and the cap is 512000
- **THEN** the full output is preserved

#### Scenario: Output exceeding cap is truncated

- **WHEN** a step produces 1MB and the cap is 512000 bytes
- **THEN** the output is truncated to 512000 bytes

### Requirement: Commands are restricted to workspace directory

The runner SHALL verify the working directory is within `Goodwizard.Config.workspace()`. Path traversal SHALL be rejected.

#### Scenario: Command in workspace executes

- **WHEN** the working directory is within the workspace
- **THEN** the command executes normally

#### Scenario: Path traversal is rejected

- **WHEN** a command attempts to use `../` to escape the workspace
- **THEN** the runner returns an error and does not execute the command
