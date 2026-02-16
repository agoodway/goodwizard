## Why

This is the execution engine — the core of the Workflow runtime. It takes a `Pipeline` struct (produced by either the pipeline parser or workflow file parser) and runs each step sequentially, piping stdout between steps, halting on approval gates, and enforcing safety constraints (timeouts, output caps, workspace restriction).

The runner is deliberately simple: sequential execution with stdout piping. We intentionally defer DAG-based parallel execution (via JidoRunic) to a later phase — the core value proposition is approval gates and resume, not parallelism.

## What Changes

- Add `Goodwizard.Workflow.Runner` module — the pipeline execution engine
- Execute shell command steps via `System.cmd/3` (not `sh -c` to avoid injection) with configurable timeout per step
- Pipe stdout from step N as stdin to step N+1 (via temporary file or Port stdin)
- On approval step: halt execution, serialize state via `Workflow.State`, build `ApprovalRequest`, return `needs_approval` envelope
- On resume: load state from token, apply approve/deny decision, continue execution from the halted point or return `cancelled` envelope
- Evaluate `condition` fields — skip steps when condition is false (e.g., `$approve.approved == false`)
- Enforce `timeoutMs` (per-pipeline kill) and `maxStdoutBytes` (per-step output cap)
- Enforce workspace restriction using the same pattern as `Shell.Exec`
- Return structured `Envelope` results for all outcomes

## Capabilities

### New Capabilities

- `workflow-runner`: Sequential pipeline execution engine with stdin piping, approval halting, resume continuation, and safety enforcement

### Modified Capabilities

_(none — this is a new module)_

## Impact

- **New module**: `Goodwizard.Workflow.Runner`
- **New file**: `lib/goodwizard/workflow/runner.ex`
- **Dependencies**: Depends on `Workflow.Step`, `Workflow.Pipeline`, `Workflow.Envelope`, `Workflow.State`, `Workflow.ApprovalRequest` from prior changes. Uses `Goodwizard.Config` for workspace path and safety settings.
- **Existing code**: No changes to any existing modules. Reuses safety patterns from `Shell.Exec` but does not call or modify that module.

## Prerequisites

- `workflow-types-and-envelope` (Step, Pipeline, Envelope structs)
- `workflow-state-persistence` (State.save/load for approval halting and resume)
