## Why

Beyond inline pipe strings, the Workflow runtime supports `.workflow` YAML workflow files with named steps, argument defaults, stdin references (`$step.stdout`), conditions (`$step.approved`), and approval markers. These files let users define reusable, versioned workflows outside of tool calls.

We already have `yaml_elixir` as a dependency (used by the brain entity system), so parsing YAML is straightforward. This module validates the YAML structure and converts it into the same `Pipeline`/`Step` structs used by the pipeline parser, keeping the downstream runner agnostic to input format.

## What Changes

- Add `Goodwizard.Workflow.WorkflowFile` module that loads and parses `.workflow` YAML files
- Validate required fields (`name`, `steps`) and optional fields (`args`, `env`)
- Parse each step's `id`, `command`, `stdin`, `approval`, and `condition`/`when` fields
- Resolve `$step.stdout` and `$step.json` references into step dependency markers on the Step structs
- Merge `args` defaults with runtime `argsJson` overrides
- Return a `Pipeline` struct identical in shape to what `PipelineParser` produces

## Capabilities

### New Capabilities

- `workflow-file`: Parse `.workflow` YAML workflow files into typed Pipeline/Step structs with step references and conditions

### Modified Capabilities

_(none — this is a new module that depends only on `workflow-types-and-envelope` structs)_

## Impact

- **New module**: `Goodwizard.Workflow.WorkflowFile`
- **New file**: `lib/goodwizard/workflow/workflow_file.ex`
- **Dependencies**: Depends on `Goodwizard.Workflow.Step` and `Goodwizard.Workflow.Pipeline` from `workflow-types-and-envelope`. Uses `yaml_elixir` (already a dep).
- **Existing code**: No changes to any existing modules

## Prerequisites

- `workflow-types-and-envelope` must be implemented first (provides Step and Pipeline structs)
