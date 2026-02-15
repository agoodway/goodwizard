## Why

The agent currently has read, write, edit, and list-dir filesystem actions but no way to search file contents by pattern. When the agent needs to find a function definition, locate a config value, or search across a project, it must either read files one by one or shell out to grep via `Shell.Exec`. A dedicated grep action gives the agent a safe, structured search tool with consistent output formatting, workspace enforcement, and no need to construct raw shell commands.

## What Changes

- Add a new `GrepFile` filesystem action that searches file/directory contents by pattern
- Use ripgrep (`rg`) as the search backend when available, falling back to system `grep`
- Support key search options: case sensitivity, recursive directory search, context lines, file type filtering, and result limits
- Enforce existing workspace restrictions via `Filesystem.resolve_path/1`
- Register the new action in the agent's tool list

## Capabilities

### New Capabilities

- `grep-tool`: Pattern-based file content search action using ripgrep/grep backends with workspace enforcement

### Modified Capabilities

_(none — this adds a new action without changing existing filesystem action behavior)_

## Impact

- **New module**: `Goodwizard.Actions.Filesystem.GrepFile` alongside existing filesystem actions
- **Agent registration**: New entry in the `tools:` list in `Goodwizard.Agent`
- **External dependency**: Runtime dependency on `rg` (preferred) or `grep` (fallback) — both are CLI tools, no new Elixir deps
- **Existing code**: No changes to existing actions or shared `Filesystem` helpers
