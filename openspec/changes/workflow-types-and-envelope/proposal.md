## Why

The Workflow runtime lets the agent run multi-step tool sequences as a single deterministic operation with explicit approval checkpoints. Before building any execution logic, we need the core data types that every other Workflow module will depend on: step definitions, pipeline containers, approval requests, and the JSON output envelope.

Defining these types first (with no IO or execution logic) gives us a stable, testable foundation. Every subsequent Workflow change (parser, runner, actions) imports these structs rather than defining ad-hoc maps.

## What Changes

- Add `Goodwizard.Workflow.Step` struct — represents one unit of work in a pipeline (shell command, approval gate, or condition check)
- Add `Goodwizard.Workflow.Pipeline` struct — an ordered list of steps with metadata (name, args, timeout, output cap)
- Add `Goodwizard.Workflow.ApprovalRequest` struct — captures the prompt, preview items, and resume token for a halted workflow
- Add `Goodwizard.Workflow.Envelope` module — formats the three possible JSON output envelopes (`ok`, `needs_approval`, `cancelled`) as Jason-encodable maps

## Capabilities

### New Capabilities

- `workflow-types`: Core data types (Step, Pipeline, ApprovalRequest structs) for the Workflow runtime
- `workflow-envelope`: JSON envelope formatter producing structured `{ok, needs_approval, cancelled}` output maps

### Modified Capabilities

_(none — this is a new, standalone module with no changes to existing code)_

## Impact

- **New modules**: `Goodwizard.Workflow.Step`, `Goodwizard.Workflow.Pipeline`, `Goodwizard.Workflow.ApprovalRequest`, `Goodwizard.Workflow.Envelope`
- **New files**: `lib/goodwizard/workflow/step.ex`, `lib/goodwizard/workflow/pipeline.ex`, `lib/goodwizard/workflow/approval_request.ex`, `lib/goodwizard/workflow/envelope.ex`
- **Dependencies**: None — uses only Jason (already a dep) and standard Elixir structs
- **Existing code**: No changes to any existing modules
