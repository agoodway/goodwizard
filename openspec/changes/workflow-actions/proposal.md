## Why

With the runtime built (types, parsers, state, runner), this final change exposes the Workflow system to the agent as two Jido Actions: `Run` (start a pipeline) and `Resume` (continue a halted pipeline). It also adds Workflow configuration to `config.toml` and registers the actions in the agent's tool list.

This is the integration layer — it wires everything together and makes workflows callable by the LLM via the existing ReAct tool-call loop.

## What Changes

- Add `Goodwizard.Actions.Workflow.Run` action — accepts `pipeline` (string or file path), `cwd`, `timeoutMs`, `maxStdoutBytes`, `argsJson`; dispatches to pipeline parser or workflow file parser based on input, then runs via `Workflow.Runner`
- Add `Goodwizard.Actions.Workflow.Resume` action — accepts `token` and `approve` (boolean); loads state, resumes or cancels via `Workflow.Runner`
- Register both actions in `Goodwizard.Agent` tools list
- Add `[workflow]` config section to `Goodwizard.Config` defaults: `enabled` (default false), `default_timeout_ms` (20000), `max_stdout_bytes` (512000), `state_ttl_minutes` (60)
- Add config documentation to `config.toml` template

## Capabilities

### New Capabilities

- `workflow-run-action`: Jido Action to run a workflow pipeline or workflow file as a single tool call
- `workflow-resume-action`: Jido Action to resume a halted workflow with approve/deny

### Modified Capabilities

- `agent`: Adds Workflow.Run and Workflow.Resume to the agent's tool list
- `config`: Adds `[workflow]` section with timeout, output cap, and TTL settings

## Impact

- **New modules**: `Goodwizard.Actions.Workflow.Run`, `Goodwizard.Actions.Workflow.Resume`
- **New files**: `lib/goodwizard/actions/workflow/run.ex`, `lib/goodwizard/actions/workflow/resume.ex`
- **Modified files**: `lib/goodwizard/agent.ex` (add two tools to list), `lib/goodwizard/config.ex` (add workflow defaults)
- **Dependencies**: Depends on all prior Workflow changes (types, parsers, state, runner)
- **Existing code**: Minimal changes — two entries added to agent tools list, one config section added

## Prerequisites

- `workflow-types-and-envelope`
- `workflow-pipeline-parser`
- `workflow-file-parser`
- `workflow-state-persistence`
- `workflow-step-runner`
