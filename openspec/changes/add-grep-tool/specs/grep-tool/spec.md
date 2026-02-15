## ADDED Requirements

### Requirement: GrepFile action searches file contents by pattern
The `Goodwizard.Actions.Filesystem.GrepFile` action SHALL use `use Jido.Action` with a schema accepting `path` (required, string), `pattern` (required, string), `case_sensitive` (optional, boolean, default true), `recursive` (optional, boolean, default true), `context_lines` (optional, integer, default 0), `file_glob` (optional, string), and `max_results` (optional, integer, default 100). The `run/2` callback SHALL resolve the path via `Filesystem.resolve_path/1`, detect whether `rg` or `grep` is available, execute the search, and return structured results.

#### Scenario: Search for a pattern in a single file
- **WHEN** `GrepFile` is called with `path` pointing to an existing file and `pattern` matching content in that file
- **THEN** it SHALL return `{:ok, %{matches: "<file>:<line>:<content>\n...", match_count: N}}` with each matching line in `file:line:content` format

#### Scenario: Search recursively in a directory
- **WHEN** `GrepFile` is called with `path` pointing to a directory and `recursive` is true (default)
- **THEN** it SHALL search all files within the directory tree and return matches from all files

#### Scenario: No matches found
- **WHEN** `GrepFile` is called with a `pattern` that does not match any content in the target path
- **THEN** it SHALL return `{:ok, %{matches: "No matches found.", match_count: 0}}`

#### Scenario: Path does not exist
- **WHEN** `GrepFile` is called with a `path` that does not exist
- **THEN** it SHALL return `{:error, "Path not found: <path>"}`

#### Scenario: Path outside workspace
- **WHEN** `GrepFile` is called and `tools.restrict_to_workspace` is enabled in config and `path` resolves outside the workspace
- **THEN** it SHALL return `{:error, "Path <path> is outside allowed directory <workspace>"}`

### Requirement: GrepFile prefers ripgrep and falls back to grep
The action SHALL check for `rg` using `System.find_executable/1` at invocation time. If `rg` is found, it SHALL be used as the search backend. Otherwise, the action SHALL fall back to system `grep`. If neither is available, the action SHALL return an error.

#### Scenario: ripgrep is available
- **WHEN** `rg` is found on the system PATH
- **THEN** the action SHALL use `rg` to execute the search

#### Scenario: ripgrep is not available but grep is
- **WHEN** `rg` is not found on the system PATH but `grep` is
- **THEN** the action SHALL use `grep` to execute the search

#### Scenario: Neither rg nor grep is available
- **WHEN** neither `rg` nor `grep` is found on the system PATH
- **THEN** it SHALL return `{:error, "No search tool available: install ripgrep (rg) or ensure grep is on PATH"}`

### Requirement: GrepFile supports case-insensitive search
The action SHALL accept a `case_sensitive` parameter (boolean, default true). When false, the search SHALL be case-insensitive.

#### Scenario: Case-insensitive search
- **WHEN** `GrepFile` is called with `case_sensitive: false` and `pattern: "hello"`
- **THEN** it SHALL match "Hello", "HELLO", "hello", and any other case variation

#### Scenario: Case-sensitive search (default)
- **WHEN** `GrepFile` is called without `case_sensitive` or with `case_sensitive: true`
- **THEN** it SHALL match only exact case

### Requirement: GrepFile supports context lines
The action SHALL accept a `context_lines` parameter (integer, default 0). When greater than zero, the output SHALL include that many lines before and after each match.

#### Scenario: Context lines included
- **WHEN** `GrepFile` is called with `context_lines: 2`
- **THEN** it SHALL include 2 lines before and 2 lines after each matching line in the output

#### Scenario: No context lines (default)
- **WHEN** `GrepFile` is called without `context_lines` or with `context_lines: 0`
- **THEN** it SHALL return only matching lines

### Requirement: GrepFile supports file glob filtering
The action SHALL accept a `file_glob` parameter (optional string). When provided, only files matching the glob pattern SHALL be searched.

#### Scenario: Filter by file extension
- **WHEN** `GrepFile` is called with `file_glob: "*.ex"` on a directory
- **THEN** it SHALL only search files ending in `.ex`

#### Scenario: No glob filter
- **WHEN** `GrepFile` is called without `file_glob`
- **THEN** it SHALL search all non-binary files

### Requirement: GrepFile limits results
The action SHALL accept a `max_results` parameter (integer, default 100). Output SHALL be truncated to the specified number of matching lines. Output text SHALL be truncated at 10,000 characters with a summary of omitted content.

#### Scenario: Results exceed max_results
- **WHEN** the search produces more than `max_results` matching lines
- **THEN** it SHALL return only the first `max_results` lines and include a note: "(truncated, showing <max_results> of <total> matches)"

#### Scenario: Output exceeds character limit
- **WHEN** the formatted output exceeds 10,000 characters
- **THEN** it SHALL truncate the output and append "... (truncated, <N> more chars)"

### Requirement: GrepFile uses System.cmd for safe execution
The action SHALL invoke `rg` or `grep` via `System.cmd/3` with arguments passed as a list (not shell-interpolated). The action SHALL NOT use `sh -c` or any shell evaluation.

#### Scenario: Pattern with shell metacharacters
- **WHEN** `GrepFile` is called with a `pattern` containing shell metacharacters (e.g., `$`, `;`, `|`)
- **THEN** the characters SHALL be treated as literal search pattern characters, not shell commands

### Requirement: GrepFile is registered as an agent tool
The `Goodwizard.Actions.Filesystem.GrepFile` module SHALL be added to the `tools:` list in `Goodwizard.Agent`, alongside existing filesystem actions.

#### Scenario: Agent can invoke grep_file
- **WHEN** the agent is initialized
- **THEN** `grep_file` SHALL appear in the agent's available tool list
