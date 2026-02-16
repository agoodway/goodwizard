## Context

This is the execution engine for the Workflow runtime. It takes a `Pipeline` struct (from either parser) and runs steps sequentially, piping stdout between them, halting on approval gates, and enforcing safety constraints (timeouts, output caps, workspace restriction).

The project already has shell execution patterns in `Goodwizard.Actions.Shell.Exec` — workspace path restriction, timeout via `Task.yield/2`, and output truncation. The runner reuses these safety patterns but does not call `Shell.Exec` directly, because it needs tighter control over stdin/stdout piping and per-step lifecycle.

Dependencies: `Workflow.Step` and `Workflow.Pipeline` (from `workflow-types-and-envelope`), `Workflow.Envelope` (output formatting), `Workflow.State` (from `workflow-state-persistence` for halt/resume).

## Goals / Non-Goals

**Goals:**

- Execute pipeline steps sequentially, piping stdout from step N as stdin to step N+1
- Execute shell commands via `System.cmd/3` with explicit argv (no `sh -c`)
- Halt on approval steps: serialize state, return `needs_approval` envelope
- Resume from token: load state, apply decision, continue or cancel
- Evaluate `condition` fields and skip steps when false
- Enforce `timeoutMs` as per-pipeline wall-clock kill
- Enforce `maxStdoutBytes` as per-step output cap
- Restrict command execution to workspace directory
- Return structured `Envelope` results for all outcomes

**Non-Goals:**

- Parallel or DAG-based execution (deferred to JidoRunic)
- Retry logic or step-level error recovery
- Streaming output during execution
- Interactive stdin from user (stdin only from previous step)
- Shell metacharacter support (argv only, no `sh`)

## Decisions

### 1. Sequential execution with stdout piping via accumulator

`Enum.reduce_while/3` over `pipeline.steps`, threading the previous step's stdout. Each step receives the accumulator as stdin.

**Alternative considered**: Process-per-step with GenStage. Rejected — serial execution doesn't benefit from it.

### 2. Shell commands via `System.cmd/3` with explicit argv

Commands split into `[executable | args]` and passed to `System.cmd/3`. Avoids `sh -c` shell injection. When stdin is needed, fall back to `Port.open/2` with `{:spawn_executable, path}`.

### 3. Approval halt serializes state and returns immediately

On `:approve` step: collect completed outputs, capture remaining steps, call `State.save/1`, build `ApprovalRequest`, return `Envelope.needs_approval/1`. No background process.

### 4. Resume loads state, applies decision

`Runner.resume(token, decision)`: load state via `State.load/1`, if `:deny` delete state and return `Envelope.cancelled/1`, if `:approve` continue from remaining steps with accumulated outputs.

### 5. Condition evaluation via simple expression matching

Conditions like `$steps.lint.exit_code == 0` evaluated against accumulated outputs. Supports `$steps.<id>.<field>`, `$approve.<field>`, comparison operators `==`/`!=`, and literal values.

**Alternative considered**: `Code.eval_string/2`. Rejected for security.

### 6. Safety enforcement mirrors Shell.Exec patterns

- **Timeout**: Pipeline-level via `Task.async/1` + `Task.yield/2`
- **Output cap**: Per-step `byte_size` check, truncate on exceed
- **Workspace restriction**: Verify working directory within `Config.workspace()`, reject path traversal

## Risks / Trade-offs

- **Stdin passing**: `System.cmd/3` lacks native stdin support. Port fallback adds complexity. Isolated in private helper.
- **No streaming**: All stdout collected before next step. Acceptable for sequential model.
- **Condition scope creep**: Only `==` and `!=` in v1. Document limitation.
- **Temp file cleanup**: Stdin temp files need cleanup in `after` block.
- **Resume token expiry**: State may be cleaned up before user responds. Include expiry time in `ApprovalRequest`.
