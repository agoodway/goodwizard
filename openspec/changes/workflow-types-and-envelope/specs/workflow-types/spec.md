## ADDED Requirements

### Requirement: Step struct represents a single unit of work

The `Goodwizard.Workflow.Step` struct SHALL define a single step in a workflow pipeline. It MUST include fields for `type` (atom: `:exec`, `:approve`, or `:openclaw_invoke`), `command` (string, the shell command or tool name), `flags` (map of parsed flag key-value pairs), `stdin_ref` (optional reference to a previous step's output), `condition` (optional condition string for conditional execution), and `id` (optional string identifier for referencing this step's output).

#### Scenario: Create an exec step

- **WHEN** a Step struct is created with type `:exec` and command `"ls -la"`
- **THEN** the struct has `type: :exec`, `command: "ls -la"`, and default values for optional fields

#### Scenario: Create an approval step

- **WHEN** a Step struct is created with type `:approve` and flags `%{prompt: "Apply changes?"}`
- **THEN** the struct has `type: :approve` and the prompt is accessible via the flags map

#### Scenario: Step type must be a recognized atom

- **WHEN** a Step struct is created with type `:exec`, `:approve`, or `:openclaw_invoke`
- **THEN** the struct is valid

### Requirement: Pipeline struct holds an ordered list of steps with metadata

The `Goodwizard.Workflow.Pipeline` struct SHALL contain a `steps` field (list of Step structs in execution order), a `name` field (optional string), a `timeout_ms` field (integer, default 20000), and a `max_stdout_bytes` field (integer, default 512000).

#### Scenario: Create a pipeline with defaults

- **WHEN** a Pipeline struct is created with only a steps list
- **THEN** `timeout_ms` defaults to 20000 and `max_stdout_bytes` defaults to 512000

#### Scenario: Pipeline preserves step order

- **WHEN** a Pipeline is created with steps [step_a, step_b, step_c]
- **THEN** `pipeline.steps` returns the steps in the same order [step_a, step_b, step_c]

#### Scenario: Pipeline name is optional

- **WHEN** a Pipeline is created without a name
- **THEN** the `name` field is nil

### Requirement: ApprovalRequest struct captures halt context

The `Goodwizard.Workflow.ApprovalRequest` struct SHALL include `prompt` (string shown to the user), `preview_items` (list of strings for context), `token` (resume token string), and `step_index` (integer index of the halting step in the pipeline).

#### Scenario: Create an approval request

- **WHEN** an ApprovalRequest is created with prompt "Deploy to production?", token "abc123", and step_index 2
- **THEN** all fields are accessible on the struct

#### Scenario: Preview items default to empty list

- **WHEN** an ApprovalRequest is created without preview_items
- **THEN** `preview_items` defaults to an empty list `[]`
