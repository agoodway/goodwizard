## Context

The agent has four filesystem actions (ReadFile, WriteFile, EditFile, ListDir) and a Shell.Exec action. When the agent needs to search file contents it currently reads files individually or constructs raw shell commands. A dedicated grep action provides a structured, safe alternative with consistent output and workspace enforcement.

All filesystem actions follow the same pattern: `use Jido.Action` with a schema, `run/2` callback using `Filesystem.resolve_path/1` for path resolution and workspace enforcement, and `{:ok, map}` / `{:error, string}` return values.

## Goals / Non-Goals

**Goals:**
- Provide a structured file content search action that fits the existing filesystem action pattern
- Use ripgrep (`rg`) when available for speed, fall back to system `grep`
- Support common search options: case sensitivity, recursive search, context lines, file glob filtering, result limits
- Enforce workspace restrictions identically to other filesystem actions
- Return structured, LLM-friendly output with file paths, line numbers, and matched content

**Non-Goals:**
- Replacing or wrapping Shell.Exec for general shell operations
- Supporting binary file search or non-UTF-8 content
- Adding ripgrep as an Elixir dependency — we shell out to the CLI tool
- Building a full-text search index or caching layer

## Decisions

### Decision 1: Shell out to rg/grep rather than pure Elixir

**Choice**: Use `System.cmd/3` to invoke `rg` or `grep` as an external process.

**Rationale**: ripgrep is significantly faster than Elixir-native file reading + regex matching for large codebases. The grep fallback ensures the action works everywhere. Both tools handle binary detection, encoding, and recursive traversal natively.

**Alternatives considered**:
- Pure Elixir (File.stream + Regex.match): Simpler, no external dependency, but much slower on large trees and requires reimplementing recursive traversal, binary detection, and glob filtering.

### Decision 2: Runtime detection of rg availability

**Choice**: Check for `rg` via `System.find_executable/1` at action invocation time. Cache the result in a module attribute or process dictionary to avoid repeated lookups.

**Rationale**: The action must work on systems without ripgrep. Checking at runtime (not compile time) handles environments where rg is installed after the app is compiled.

### Decision 3: Resolve path first, then pass to rg/grep

**Choice**: Use `Filesystem.resolve_path/1` to validate and expand the search path before passing it to the external command.

**Rationale**: This maintains identical workspace enforcement as all other filesystem actions. The resolved absolute path is passed to rg/grep so no path traversal can escape the workspace.

### Decision 4: Structured output format

**Choice**: Return `{:ok, %{matches: string, match_count: integer}}` where `matches` is a newline-separated string of `file:line:content` entries.

**Rationale**: Consistent with how ReadFile returns `%{content: string}`. The `file:line:content` format is standard grep output and LLM-friendly. Including `match_count` helps the agent decide whether to refine the search.

### Decision 5: Result truncation

**Choice**: Default max results of 100 matches, configurable via `max_results` parameter. Truncate output at 10,000 characters (matching Shell.Exec's limit) with a summary of omitted results.

**Rationale**: Unbounded grep output could overwhelm the LLM context window. The default limit is generous enough for most searches while protecting against runaway queries.

## Risks / Trade-offs

- **[External dependency]** → Both `rg` and `grep` are CLI tools, not Elixir deps. If neither is available, the action returns a clear error. This is acceptable since grep is present on virtually all Unix systems.
- **[Shell execution]** → Using `System.cmd/3` (not `sh -c`) avoids shell injection since arguments are passed as a list, not interpolated into a command string.
- **[Output size]** → Large searches could produce massive output. Mitigated by `max_results` and character truncation.
