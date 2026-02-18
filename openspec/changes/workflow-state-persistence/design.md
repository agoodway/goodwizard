## Context

When a workflow pipeline hits an approval gate, execution halts and a resume token is returned. The user or agent can later resume with approve/deny. For this to work across process restarts, halted state must be persisted to disk.

The project uses file-backed JSON storage for structured data: `ScheduledTaskStore` persists scheduled tasks as individual JSON files under `workspace/scheduling/scheduled_tasks/`. Goodwizard has a Nebulex local ETS cache (`Goodwizard.Cache`) for hot-path reads, and `Goodwizard.Config` provides the workspace path.

The `workflow-types-and-envelope` change (prerequisite) defines the `Step`, `Pipeline`, and `ApprovalRequest` structs that this module serializes.

## Goals / Non-Goals

**Goals:**

- Persist halted workflow state to disk so it survives process restarts
- Generate URL-safe resume tokens for each halted workflow
- Load persisted state by token for workflow resumption
- Delete state files when a workflow completes or is cancelled
- Clean up expired state files based on a configurable TTL (default: 1 hour)
- Cache active workflow states in `Goodwizard.Cache` for fast read-through
- Follow existing workspace conventions (file-per-entity, workspace-relative paths)

**Non-Goals:**

- Database-backed storage
- Distributed or multi-node state coordination
- State migration or versioning across schema changes
- Workflow execution logic (persistence only)

## Decisions

### 1. Token generation via `:crypto.strong_rand_bytes`

Resume tokens are generated using `:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)`, producing a 22-character URL-safe random string. No external dependencies.

**Alternative considered**: Sqids (compact, hashid-style tokens). Rejected because the `sqids` dependency is being removed in parallel (`switch-entity-id-to-uuid`).

**Alternative considered**: UUIDv7 via `uniq`. Rejected to avoid coupling to the UUID migration. Simple random string is sufficient for short-lived tokens.

### 2. File-per-state in `workspace/workflow/state/`

Each halted workflow saved as `<token>.json` under `workspace/workflow/state/`. Follows the same pattern as `ScheduledTaskStore` (`workspace/scheduling/scheduled_tasks/<job_id>.json`).

**Alternative considered**: Single manifest file. Rejected — concurrent writes would require locking.

### 3. State contents

Each JSON file contains: `token`, `completed_outputs` (map of step_id to output), `remaining_steps` (serialized step structs), `approval_context` (prompt, preview items, requesting step), `pipeline_metadata` (name, args, timeout, output cap), `created_at` (ISO 8601), `version` (integer, currently 1).

### 4. Focused API

`Goodwizard.Workflow.State` provides: `generate_token/0`, `save/2` (token + state map), `load/1` (by token, cache read-through), `delete/1` (file + cache), `cleanup/1` (remove expired files by TTL).

### 5. Cache integration

`load/1` checks `Goodwizard.Cache` first (key: `"workflow:state:<token>"`). On miss, reads disk and populates cache. `save/2` writes to both. `delete/1` removes from both.

### 6. TTL-based cleanup

`cleanup/1` accepts TTL in seconds (default 3600). Lists files, checks `created_at`, deletes expired ones. Malformed files are also deleted during cleanup. Caller-driven — no built-in timer.

## Risks / Trade-offs

- **Race between save and crash**: If process crashes between generating token and writing file, caller has a token with no state. Resume returns "not found" error — user can re-run.
- **No file locking**: Mitigated by 128-bit random tokens — collision probability is negligible.
- **Cleanup is caller-driven**: Expired files accumulate without explicit cleanup. Mitigated by small file sizes.
- **Cache lost on restart**: ETS cache is in-memory. `load/1` falls through to disk on miss.
