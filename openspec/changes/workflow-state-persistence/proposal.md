## Why

When a workflow pipeline hits an approval gate, execution halts and returns a resume token. The user (or agent) can later resume with `approve: true/false` to continue or cancel the workflow. This requires persisting the halted workflow state — completed step outputs, remaining steps, and approval context — to disk so it survives process restarts.

The token system needs to be compact (URL-safe, short) and the storage needs cleanup to avoid unbounded growth. We use Sqids (already a dep) for token generation and file-backed JSON for storage, following the same workspace-based persistence pattern used by brain entities and sessions.

## What Changes

- Add `Goodwizard.Workflow.State` module for workflow state serialization, persistence, and retrieval
- Generate compact resume tokens using Sqids
- Store halted state as JSON files under `workspace/workflow/state/<token>.json`
- Include in state: completed step outputs (map of step_id to output), remaining steps, approval request context, creation timestamp, pipeline metadata
- Provide `save/2`, `load/1`, `delete/1`, and `cleanup/1` functions
- `cleanup/1` removes expired tokens based on configurable TTL (default: 1 hour)
- Use `Goodwizard.Cache` for read-through caching of active tokens

## Capabilities

### New Capabilities

- `workflow-state-persistence`: Resume token generation and file-backed workflow state persistence with TTL cleanup

### Modified Capabilities

_(none — this is a new standalone module)_

## Impact

- **New module**: `Goodwizard.Workflow.State`
- **New file**: `lib/goodwizard/workflow/state.ex`
- **New directory**: `workspace/workflow/state/` created on first save
- **Dependencies**: Uses `Sqids` (already a dep), `Jason` (already a dep), `Goodwizard.Cache`, `Goodwizard.Config` for workspace path
- **Existing code**: No changes to any existing modules

## Prerequisites

- `workflow-types-and-envelope` must be implemented first (provides structs that get serialized)
