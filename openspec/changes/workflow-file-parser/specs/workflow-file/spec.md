## ADDED Requirements

### Requirement: YAML workflow files are loaded and validated

The `Goodwizard.Workflow.WorkflowFile` module SHALL load `.workflow` YAML files and validate that required top-level fields (`name`, `steps`) are present. Missing required fields SHALL produce an `{:error, reason}` tuple.

#### Scenario: Valid workflow file is loaded

- **WHEN** `parse_file/1` is called with a valid `.workflow` YAML file containing `name` and `steps`
- **THEN** it returns `{:ok, %Pipeline{}}` with the parsed pipeline

#### Scenario: Missing name field produces error

- **WHEN** `parse_file/1` is called with a YAML file missing the `name` field
- **THEN** it returns `{:error, reason}` indicating the missing field

#### Scenario: Missing steps field produces error

- **WHEN** `parse_file/1` is called with a YAML file missing the `steps` field
- **THEN** it returns `{:error, reason}` indicating the missing field

#### Scenario: Non-existent file path produces error

- **WHEN** `parse_file/1` is called with a path to a file that does not exist
- **THEN** it returns `{:error, reason}` indicating the file was not found

#### Scenario: Malformed YAML produces error

- **WHEN** `parse_file/1` is called with a file containing invalid YAML syntax
- **THEN** it returns `{:error, reason}` indicating a YAML parse error

### Requirement: Steps are parsed with required id and command fields

Each step in the `steps` list MUST have an `id` (unique string) and a `command` (string). Optional fields include `stdin`, `approval` (boolean), and `condition`/`when` (string).

#### Scenario: Step with id and command is parsed

- **WHEN** a step has `id: "lint"` and `command: "mix credo"`
- **THEN** the resulting Step struct has `id: "lint"` and `command: "mix credo"`

#### Scenario: Step missing id produces error

- **WHEN** a step is missing the `id` field
- **THEN** `parse_file/1` returns `{:error, reason}` indicating the missing step id

#### Scenario: Duplicate step ids produce error

- **WHEN** two steps have the same `id` value
- **THEN** `parse_file/1` returns `{:error, reason}` indicating duplicate ids

#### Scenario: Approval step is recognized

- **WHEN** a step has `approval: true` and `command: "Deploy to production?"`
- **THEN** the resulting Step struct has type `:approve`

### Requirement: Step references are resolved to dependency markers

`$step.stdout` and `$step.json` patterns in a step's `stdin` field SHALL be resolved into dependency markers on the Step struct. Forward references (to a later step) SHALL be rejected.

#### Scenario: stdout reference is resolved

- **WHEN** step B has `stdin: "$lint.stdout"` and step "lint" precedes it
- **THEN** step B's Step struct includes a dependency on step "lint" with output type `:stdout`

#### Scenario: json reference is resolved

- **WHEN** step B has `stdin: "$fetch.json"` and step "fetch" precedes it
- **THEN** step B's Step struct includes a dependency on step "fetch" with output type `:json`

#### Scenario: Forward reference produces error

- **WHEN** step A references `$later_step.stdout` and "later_step" appears after step A
- **THEN** `parse_file/1` returns `{:error, reason}` indicating a forward reference

#### Scenario: Reference to non-existent step produces error

- **WHEN** a step references `$nonexistent.stdout`
- **THEN** `parse_file/1` returns `{:error, reason}` indicating unknown step reference

### Requirement: Args defaults are merged with runtime overrides

The YAML `args` map provides default values. Runtime overrides passed via `parse_file/2` opts are shallow-merged on top. Arg values are interpolated into step commands using `${arg_name}` syntax.

#### Scenario: Default args are interpolated into commands

- **WHEN** args define `env: "staging"` and a step command contains `"deploy ${env}"`
- **THEN** the parsed step command is `"deploy staging"`

#### Scenario: Runtime override replaces default

- **WHEN** args default `env: "staging"` but runtime override provides `env: "production"`
- **THEN** the parsed step command uses `"production"`

#### Scenario: Args without references pass through unchanged

- **WHEN** a step command contains no `${...}` patterns
- **THEN** the command is unchanged regardless of args values

### Requirement: Parse result is a Pipeline struct identical to PipelineParser output

The return value of `parse_file/1` SHALL be a `%Pipeline{}` struct with `steps`, `name`, `timeout_ms`, and `max_stdout_bytes` fields, identical in shape to what `PipelineParser.parse/1` produces.

#### Scenario: Pipeline name comes from YAML name field

- **WHEN** the YAML file has `name: "deploy-pipeline"`
- **THEN** the Pipeline struct has `name: "deploy-pipeline"`

#### Scenario: Timeout comes from YAML timeout field

- **WHEN** the YAML file has `timeout: 30000`
- **THEN** the Pipeline struct has `timeout_ms: 30000`
