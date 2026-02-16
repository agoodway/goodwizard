## Why

Workflow pipelines are expressed as pipe-separated command strings like `"exec --shell 'inbox list --json' | exec --stdin json --shell 'inbox categorize --json' | approve --prompt 'Apply changes?'"`. The agent sends these strings in tool calls; we need a parser that turns them into the `Step` structs defined in `workflow-types-and-envelope`.

This parser is intentionally simple — it's a tokenizer + flag parser, not a programming language. The grammar is small enough for AI to generate reliably.

## What Changes

- Add `Goodwizard.Workflow.PipelineParser` module that parses pipe-separated command strings into a `Pipeline` struct containing a list of `Step` structs
- Handle quoting (single and double quotes) so embedded shell commands with spaces parse correctly
- Recognize workflow step types: `exec` (shell command), `approve` (approval gate), and `openclaw.invoke` (tool invocation)
- Parse step flags: `--shell`, `--stdin`, `--prompt`, `--preview-from-stdin`, `--limit`, `--each`, `--item-key`, `--args-json`

## Capabilities

### New Capabilities

- `workflow-pipeline-parser`: Parse pipe-separated workflow command strings into typed Step/Pipeline structs

### Modified Capabilities

_(none — this is a new module that depends only on `workflow-types-and-envelope` structs)_

## Impact

- **New module**: `Goodwizard.Workflow.PipelineParser`
- **New file**: `lib/goodwizard/workflow/pipeline_parser.ex`
- **Dependencies**: Depends on `Goodwizard.Workflow.Step` and `Goodwizard.Workflow.Pipeline` from `workflow-types-and-envelope`
- **Existing code**: No changes to any existing modules

## Prerequisites

- `workflow-types-and-envelope` must be implemented first (provides Step and Pipeline structs)
