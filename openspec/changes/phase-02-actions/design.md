## Context

Phase 2 implements the 5 core Jido Actions that give the LLM agent its ability to interact with the filesystem and execute shell commands. These actions are ported from Nanobot's Python tool implementations (`filesystem.py`, `shell.py`) to Elixir using the `Jido.Action` behaviour pattern.

Phase 1 must be complete (Mix project scaffold, Config GenServer) before these actions can compile, but the design is independent. The actions will later be registered in jido_ai's Tool Registry (Phase 3) for LLM tool-calling.

## Goals / Non-Goals

**Goals:**
- 5 Jido Actions: ReadFile, WriteFile, EditFile, ListDir, Exec
- Each action uses `use Jido.Action` with a schema and `run/2` callback
- Behaviour-preserving port from the Python originals
- Configurable safety constraints (allowed_dir, deny patterns, timeout) via action params or context
- Comprehensive error handling returning descriptive `{:error, reason}` tuples

**Non-Goals:**
- Tool Registry registration (Phase 3)
- LLM tool schema conversion via ToolAdapter (Phase 3)
- Async/streaming execution (actions are synchronous)
- File watching or change detection
- Shell session persistence (each Exec is stateless)

## Decisions

### 1. Module namespace: `Goodwizard.Actions.Filesystem.*` and `Goodwizard.Actions.Shell.*`

**Decision**: Group filesystem actions under `Goodwizard.Actions.Filesystem` and shell actions under `Goodwizard.Actions.Shell`.

**Rationale**: Mirrors the Python package structure (`tools/filesystem.py`, `tools/shell.py`). Clear grouping makes it easy to register all filesystem tools or all shell tools as a set. Jido Actions are modules, so namespacing is natural.

**Alternatives considered**: Flat namespace (`Goodwizard.Actions.ReadFile`) — rejected because it doesn't scale as actions grow. Single module with multiple actions — rejected because Jido expects one module per action.

### 2. Path resolution as a shared helper

**Decision**: Extract `Goodwizard.Actions.Filesystem.resolve_path/2` as a shared function used by all filesystem actions.

**Rationale**: All 4 filesystem actions need tilde expansion and optional allowed_dir enforcement. The Python code uses `_resolve_path()` the same way. Keeping it in the `Filesystem` namespace avoids a separate utility module for a single function.

### 3. `allowed_dir` passed via action params, not hardcoded

**Decision**: Each filesystem action accepts an optional `allowed_dir` parameter in its schema. If present, paths are validated against it.

**Rationale**: The Python implementation takes `allowed_dir` in the constructor. In Jido, actions are stateless modules — configuration flows through params. This lets the ReAct strategy inject workspace restrictions at call time using config values from `Goodwizard.Config`.

### 4. Error returns as `{:error, String.t()}` not exception raising

**Decision**: Actions return `{:error, "descriptive message"}` for all failure cases rather than raising exceptions.

**Rationale**: Jido's action pipeline expects `{:ok, result}` or `{:error, reason}` tuples. The LLM needs error messages as text to reason about failures. Exceptions would crash the action pipeline. Matches the Python pattern of returning `"Error: ..."` strings.

### 5. Exec safety guards via regex deny patterns

**Decision**: Port the Python deny-pattern list as compiled Elixir regexes. Check command against deny patterns before execution.

**Rationale**: Direct port of working Nanobot safety logic. Regex-based guards are best-effort (not a security sandbox) but prevent common destructive mistakes. The deny list covers: `rm -rf`, `format`/`mkfs`/`diskpart`, `dd if=`, disk writes, `shutdown`/`reboot`, and fork bombs.

**Alternatives considered**: Using a proper sandbox (e.g., cgroups, seccomp) — too heavy for this phase, can layer on later. Allow-list only — too restrictive for general agent use.

### 6. Exec uses `System.cmd/3` with Port for timeout

**Decision**: Use Elixir's `System.cmd/3` for simple execution and a raw Port with `Process.send_after` for timeout enforcement.

**Rationale**: `System.cmd/3` is the simplest way to capture stdout but doesn't support timeouts natively. For timeout support, we use a Task with `Task.await/2` wrapping `System.cmd/3`. If the task exceeds the timeout, we kill it. This avoids the complexity of raw ports while still enforcing time limits.

### 7. Output truncation at 10,000 characters

**Decision**: Truncate combined stdout+stderr output at 10,000 characters, matching Python's behavior.

**Rationale**: LLM context windows are expensive. Very long command outputs provide diminishing returns. 10k chars is enough for most diagnostic output while preventing runaway token usage. The truncation message includes how many characters were omitted.

## Risks / Trade-offs

**[Exec safety guards are best-effort]** → The regex deny list can be bypassed by encoding, aliasing, or indirect commands. This is acceptable — the guards prevent accidents, not adversarial attacks. A proper sandbox is a future concern.

**[No stderr separation in System.cmd]** → `System.cmd/3` merges stderr into stdout by default. We use `stderr_to_stdout: true` explicitly and prefix stderr sections. This matches the Python behavior closely enough.

**[EditFile ambiguity check returns error, not warning]** → Python returns a "Warning" string but doesn't actually edit. We return `{:error, ...}` which is cleaner — the caller (LLM) gets a clear signal to retry with more context. Slight behavior difference from Python but better semantics.

**[Tilde expansion only for ~, not ~user]** → `Path.expand/1` handles `~` but not `~otheruser`. This matches Nanobot behavior and is fine for a single-user agent.
