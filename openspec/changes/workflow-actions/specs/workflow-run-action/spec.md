## ADDED Requirements

### Requirement: Run action accepts pipeline string or file path

The `Goodwizard.Actions.Workflow.Run` action SHALL accept a `pipeline` parameter (string). If the value ends with `.workflow`, `.yaml`, or `.yml`, it SHALL be dispatched to `Workflow.WorkflowFile`. Otherwise, it SHALL be dispatched to `Workflow.PipelineParser`.

#### Scenario: Pipe string is parsed and executed

- **WHEN** the Run action receives `pipeline: "exec --shell 'ls' | approve --prompt 'ok?'"`
- **THEN** the string is parsed via PipelineParser and executed via Runner

#### Scenario: Workflow file is loaded and executed

- **WHEN** the Run action receives `pipeline: "deploy.workflow"`
- **THEN** the file is loaded via WorkflowFile and executed via Runner

### Requirement: Run action supports optional execution parameters

The action SHALL accept optional `timeout_ms`, `max_stdout_bytes`, `cwd`, and `args_json` parameters that override config defaults.

#### Scenario: Custom timeout overrides config default

- **WHEN** the Run action receives `timeout_ms: 60000`
- **THEN** the pipeline uses 60000ms timeout instead of the config default

#### Scenario: Default timeout from config is used

- **WHEN** the Run action does not specify `timeout_ms`
- **THEN** the pipeline uses `Goodwizard.Config` `default_timeout_ms` value

### Requirement: Run action checks workflow enabled config

The action SHALL check `Goodwizard.Config.get(["workflow", "enabled"])` before executing. If disabled, it SHALL return an error.

#### Scenario: Workflow disabled returns error

- **WHEN** the Run action is called with `workflow.enabled = false`
- **THEN** it returns `{:error, "Workflow system is disabled. Set [workflow] enabled = true in config.toml"}`

#### Scenario: Workflow enabled proceeds to execution

- **WHEN** the Run action is called with `workflow.enabled = true`
- **THEN** parsing and execution proceed normally

### Requirement: Run action returns structured Envelope output

The action SHALL return the Runner's Envelope output as its result: `ok`, `needs_approval`, or `cancelled` maps.

#### Scenario: Successful pipeline returns ok envelope

- **WHEN** the pipeline completes successfully
- **THEN** the action returns `{:ok, %{"status" => "ok", "result" => ...}}`

#### Scenario: Approval halt returns needs_approval envelope

- **WHEN** the pipeline halts at an approval gate
- **THEN** the action returns `{:ok, %{"status" => "needs_approval", "token" => ..., "prompt" => ...}}`
