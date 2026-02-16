## Context

Beyond inline pipe strings, the Workflow runtime supports `.workflow` YAML files with named steps, argument defaults, stdin references (`$step.stdout`), conditions (`$step.approved`), and approval markers. These files let users define reusable, versioned workflows outside of tool calls.

The project already has `yaml_elixir` as a dependency (used by the brain entity system). This module validates the YAML structure and converts it into the same `Pipeline`/`Step` structs from `workflow-types-and-envelope`, keeping the downstream runner agnostic to input format.

## Goals / Non-Goals

**Goals:**

- Load and parse `.workflow` YAML files into `Pipeline`/`Step` structs
- Validate required top-level fields (`name`, `steps`) and reject malformed files with clear errors
- Support optional fields (`args`, `env`, `description`, `timeout`)
- Parse each step's `id`, `command`, `stdin`, `approval`, and `condition`/`when` fields
- Resolve `$step.stdout` and `$step.json` references into step dependency markers on Step structs
- Merge `args` defaults from YAML with runtime `args_override` maps
- Single public entry point: `WorkflowFile.parse_file/2`

**Non-Goals:**

- Inline pipeline string parsing (separate `workflow-pipeline-parser` change)
- Workflow execution (handled by the runner)
- File discovery or directory scanning (caller provides file path)
- Nested workflow imports or `$include` directives

## Decisions

### 1. Single public entry point: `parse_file/2`

`WorkflowFile.parse_file(path, opts \\ [])` loads, decodes, validates, resolves references, merges args, and returns `{:ok, %Pipeline{}}` or `{:error, reason}`.

**Alternative considered**: Separate `load/1` and `parse/1`. Rejected because callers always need the full pipeline.

### 2. YAML validation via pattern matching

Required fields checked with pattern matching on decoded map. Missing or wrong-typed fields produce tagged error tuples like `{:error, {:missing_field, "name"}}`. No external schema validation library.

### 3. Step references resolved to dependency list on Step struct

`$step.stdout` and `$step.json` patterns in `stdin` or `command` fields are parsed into `depends_on` entries: `{step_id, :stdout | :json}` tuples. Forward references (referencing a later step) are rejected.

### 4. Args merging: defaults under runtime overrides

YAML `args` provides defaults. `parse_file/2` accepts optional `args_override` keyword shallow-merged on top. Arg values interpolated into commands via `${arg_name}` syntax.

### 5. Step IDs are required and unique

Every step must have an `id` field. Duplicates produce an error. IDs must match `~r/^[a-zA-Z0-9_-]+$/`.

## Risks / Trade-offs

- **YAML parse errors are opaque**: `yaml_elixir` error messages are Erlang-style. Wrapped in `{:error, {:yaml_parse_error, message}}`.
- **No streaming for large files**: Entire file loaded to memory. Acceptable — workflow files are small.
- **Simple string replacement for args**: `${arg_name}` replaced via `String.replace/3`. No escaping or nested expressions.
- **Forward references forbidden**: Steps can only reference outputs of preceding steps.
