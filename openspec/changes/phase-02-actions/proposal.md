# Phase 2: Jido Actions (Filesystem + Shell Tools)

## Why

The LLM agent needs concrete tools to interact with the filesystem and execute shell commands. These 5 core actions are the foundation of everything the agent can do — reading, writing, editing files, listing directories, and running commands. They must be implemented as pure Jido Actions before the ReAct strategy can use them as tools.

## What

Implement 5 Jido Actions with `use Jido.Action`, each with a schema and `run/2` callback. These actions will be registered in jido_ai's Tool Registry and converted to LLM tool definitions via `Jido.AI.ToolAdapter`.

### Filesystem Actions

**ReadFile** — Port from `nanobot/agent/tools/filesystem.py:ReadFileTool` (lines 17-57):
- Expand `~` in path
- Workspace restriction enforced server-side via `Goodwizard.Config`
- Handle: file not found, not a file, permission error, encoding error

**WriteFile** — Port from `WriteFileTool` (lines 60-100):
- Create parent directories
- Write UTF-8 content
- Return byte count confirmation

**EditFile** — Port from `EditFileTool` (lines 103-161):
- Find-and-replace `old_text` with `new_text`
- Error if `old_text` not found
- Warning if `old_text` appears more than once (ambiguous)
- Replace only first occurrence

**ListDir** — Port from `ListDirTool` (lines 164-211):
- List directory entries sorted
- Prefix dirs with `[DIR]`, files with `[FILE]`
- Handle: not found, not a directory

### Shell Action

**Exec** — Port from `nanobot/agent/tools/shell.py:ExecTool` (lines 12-144):
- Safety guards: deny `rm -rf`, `format`, `mkfs`, `dd if=`, `shutdown`, fork bomb
- Optional allow patterns and workspace restriction
- Timeout (default 60s, configurable via context)
- Capture stdout + stderr, truncate at 10,000 chars
- Return exit code on non-zero

## Dependencies

None — standalone phase (can run in parallel with Phase 1).

## Reference

- `nanobot/agent/tools/filesystem.py` (212 lines)
- `nanobot/agent/tools/shell.py` (144 lines)
- `nanobot/agent/tools/base.py` (103 lines)
- jido_ai tool system: https://hexdocs.pm/jido_ai/readme.html
