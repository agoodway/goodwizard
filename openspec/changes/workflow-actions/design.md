## Context

The Workflow runtime (types, parsers, state persistence, step runner) is fully defined across four prior changes. This change is the integration layer that exposes the runtime to the LLM agent as two Jido Actions: `Workflow.Run` (start a pipeline) and `Workflow.Resume` (continue a halted pipeline). It also adds a `[workflow]` configuration section and registers both actions in the agent's tool list.

The project uses the `use Jido.Action` macro with `name`, `description`, and `schema` options, implementing a `run/2` callback. Actions return `{:ok, result_map}` or `{:error, reason}`. The agent tool list is a flat list of module names in `Goodwizard.Agent`. Config defaults are a static map in `Goodwizard.Config` with TOML file override.

## Goals / Non-Goals

**Goals:**

- Expose `Workflow.Run` as an agent tool accepting a pipeline string or file path
- Expose `Workflow.Resume` as an agent tool accepting a resume token and approve/deny boolean
- Add `[workflow]` config section with `enabled`, `default_timeout_ms`, `max_stdout_bytes`, `state_ttl_minutes`
- Register both actions in `Goodwizard.Agent` tool list
- Return structured `Envelope` output from both actions

**Non-Goals:**

- Workflow editing, listing, or management actions
- Workflow file discovery or search
- DAG-based parallel execution
- Approval notification push to external channels

## Decisions

### 1. Single `pipeline` param with dispatch heuristic

The `Run` action accepts a `pipeline` string. If it ends with `.workflow`/`.yaml`/`.yml`, dispatch to `WorkflowFile`. Otherwise, dispatch to `PipelineParser`.

**Alternative considered**: Separate `pipeline_string` and `file_path` params. Rejected — adds schema complexity. File extension heuristic is unambiguous.

### 2. Config-driven defaults with per-call overrides

`Run` reads `default_timeout_ms` and `max_stdout_bytes` from Config but allows per-call overrides via action params.

### 3. Guard on `workflow.enabled` config

Both actions check `Config.get(["workflow", "enabled"])`. If disabled (default), return `{:error, "Workflow system is disabled"}`.

### 4. Actions under `Goodwizard.Actions.Workflow` namespace

Following convention: `Actions.Workflow.Run` and `Actions.Workflow.Resume`.

## Risks / Trade-offs

- **Dispatch edge case**: A pipe string ending in `.workflow` would be misrouted. Extremely unlikely since pipe segments follow after.
- **Config availability**: Actions depend on Config GenServer. Same pattern as all other actions.
- **Disabled by default**: Users must opt in. Intentional safety — workflows execute shell commands.
