## 1. Core Runner Loop

- [ ] 1.1 Create `lib/goodwizard/workflow/runner.ex` with `run/2` accepting a Pipeline struct and opts
- [ ] 1.2 Implement `Enum.reduce_while/3` loop over pipeline steps, threading stdout accumulator
- [ ] 1.3 Return `Envelope.ok/1` on successful completion

## 2. Shell Execution

- [ ] 2.1 Implement shell command execution via `System.cmd/3` with `[executable | args]` splitting
- [ ] 2.2 Implement Port-based fallback for steps requiring stdin input
- [ ] 2.3 Capture stdout and exit code from each step

## 3. Stdout Piping

- [ ] 3.1 Pass previous step's stdout as stdin to next step
- [ ] 3.2 Handle first step (no stdin) vs subsequent steps (has stdin)
- [ ] 3.3 Write stdin to temp file when using Port-based execution

## 4. Approval Halting

- [ ] 4.1 Detect `:approve` type steps and halt the reduce loop
- [ ] 4.2 Collect completed step outputs and remaining steps
- [ ] 4.3 Call `Workflow.State.save/2` to persist halted state
- [ ] 4.4 Build `ApprovalRequest` from step flags (prompt, preview items)
- [ ] 4.5 Return `Envelope.needs_approval/1`

## 5. Resume Flow

- [ ] 5.1 Implement `resume/2` accepting token and decision (`:approve` or `:deny`)
- [ ] 5.2 Load halted state via `Workflow.State.load/1`, return error on not found
- [ ] 5.3 On `:deny`, delete state and return `Envelope.cancelled/1`
- [ ] 5.4 On `:approve`, continue execution from remaining steps with accumulated outputs

## 6. Condition Evaluation

- [ ] 6.1 Implement simple expression evaluator for condition strings
- [ ] 6.2 Support `$steps.<id>.<field>` variable references
- [ ] 6.3 Support `==` and `!=` comparison operators with literal values
- [ ] 6.4 Skip steps where condition evaluates to false

## 7. Safety Enforcement

- [ ] 7.1 Implement pipeline-level timeout via `Task.async/1` + `Task.yield/2`
- [ ] 7.2 Implement per-step output cap with `byte_size` check and truncation
- [ ] 7.3 Implement workspace restriction: verify working directory within `Config.workspace()`
- [ ] 7.4 Clean up temp files in `after` block on pipeline completion

## 8. Tests

- [ ] 8.1 Tests for sequential execution with stdout piping
- [ ] 8.2 Tests for approval halt and resume (approve and deny)
- [ ] 8.3 Tests for condition evaluation (true/false/skip)
- [ ] 8.4 Tests for timeout enforcement
- [ ] 8.5 Tests for output cap truncation
- [ ] 8.6 Tests for workspace restriction and path traversal rejection
- [ ] 8.7 Tests for error cases: invalid token, step failure, missing executable
