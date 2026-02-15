## ADDED Requirements

### Requirement: ReadFile action reads file contents
The `Goodwizard.Actions.Filesystem.ReadFile` action SHALL use `use Jido.Action` with a schema accepting `path` (required, string). The `run/2` callback SHALL expand `~` in the path, enforce workspace restrictions via server-side config, and return the file contents as a UTF-8 string.

#### Scenario: Read an existing file
- **WHEN** `ReadFile` is called with `path` pointing to an existing text file
- **THEN** it SHALL return `{:ok, %{content: "<file contents>"}}` with the full UTF-8 content

#### Scenario: File does not exist
- **WHEN** `ReadFile` is called with a `path` that does not exist
- **THEN** it SHALL return `{:error, "File not found: <path>"}`

#### Scenario: Path is not a file
- **WHEN** `ReadFile` is called with a `path` pointing to a directory
- **THEN** it SHALL return `{:error, "Not a file: <path>"}`

#### Scenario: Path outside workspace
- **WHEN** `ReadFile` is called and `tools.restrict_to_workspace` is enabled in config and `path` resolves outside the workspace
- **THEN** it SHALL return `{:error, "Path <path> is outside allowed directory <workspace>"}`

#### Scenario: Tilde expansion in path
- **WHEN** `ReadFile` is called with `path` starting with `~`
- **THEN** the system SHALL expand `~` to the user's home directory before resolving

### Requirement: WriteFile action creates or overwrites files
The `Goodwizard.Actions.Filesystem.WriteFile` action SHALL use `use Jido.Action` with a schema accepting `path` (required, string) and `content` (required, string). The `run/2` callback SHALL create parent directories if needed, enforce workspace restrictions via server-side config, write UTF-8 content, and return a byte count confirmation.

#### Scenario: Write to a new file
- **WHEN** `WriteFile` is called with a `path` that does not exist
- **THEN** it SHALL create the file, write the content, and return `{:ok, %{message: "Successfully wrote <N> bytes to <path>"}}`

#### Scenario: Write creates parent directories
- **WHEN** `WriteFile` is called with a `path` whose parent directories do not exist
- **THEN** it SHALL create all parent directories recursively before writing

#### Scenario: Overwrite an existing file
- **WHEN** `WriteFile` is called with a `path` pointing to an existing file
- **THEN** it SHALL overwrite the file with the new content and return the byte count

#### Scenario: Path outside workspace
- **WHEN** `WriteFile` is called and `tools.restrict_to_workspace` is enabled in config and `path` resolves outside the workspace
- **THEN** it SHALL return `{:error, "Path <path> is outside allowed directory <workspace>"}`

### Requirement: EditFile action performs find-and-replace
The `Goodwizard.Actions.Filesystem.EditFile` action SHALL use `use Jido.Action` with a schema accepting `path` (required, string), `old_text` (required, string), and `new_text` (required, string). The `run/2` callback SHALL enforce workspace restrictions via server-side config, find the exact `old_text` in the file and replace it with `new_text`.

#### Scenario: Successful single-occurrence replace
- **WHEN** `EditFile` is called and `old_text` appears exactly once in the file
- **THEN** it SHALL replace `old_text` with `new_text`, write the file, and return `{:ok, %{message: "Successfully edited <path>"}}`

#### Scenario: old_text not found in file
- **WHEN** `EditFile` is called and `old_text` does not exist in the file
- **THEN** it SHALL return `{:error, "old_text not found in file. Make sure it matches exactly."}`

#### Scenario: old_text appears multiple times (ambiguous)
- **WHEN** `EditFile` is called and `old_text` appears more than once in the file
- **THEN** it SHALL return `{:error, "old_text appears <N> times. Please provide more context to make it unique."}`

#### Scenario: File does not exist
- **WHEN** `EditFile` is called with a `path` that does not exist
- **THEN** it SHALL return `{:error, "File not found: <path>"}`

#### Scenario: Path outside workspace
- **WHEN** `EditFile` is called and `tools.restrict_to_workspace` is enabled in config and `path` resolves outside the workspace
- **THEN** it SHALL return `{:error, "Path <path> is outside allowed directory <workspace>"}`

### Requirement: ListDir action lists directory entries
The `Goodwizard.Actions.Filesystem.ListDir` action SHALL use `use Jido.Action` with a schema accepting `path` (required, string). The `run/2` callback SHALL enforce workspace restrictions via server-side config and list directory entries sorted alphabetically, prefixing directories with `[DIR]` and files with `[FILE]`.

#### Scenario: List a directory with files and subdirectories
- **WHEN** `ListDir` is called with a `path` containing files and directories
- **THEN** it SHALL return `{:ok, %{entries: "<sorted listing>"}}` with each entry on a new line, prefixed with `[DIR]` or `[FILE]`

#### Scenario: List an empty directory
- **WHEN** `ListDir` is called with a `path` pointing to an empty directory
- **THEN** it SHALL return `{:ok, %{entries: "Directory <path> is empty"}}`

#### Scenario: Directory does not exist
- **WHEN** `ListDir` is called with a `path` that does not exist
- **THEN** it SHALL return `{:error, "Directory not found: <path>"}`

#### Scenario: Path is not a directory
- **WHEN** `ListDir` is called with a `path` pointing to a file
- **THEN** it SHALL return `{:error, "Not a directory: <path>"}`

#### Scenario: Path outside workspace
- **WHEN** `ListDir` is called and `tools.restrict_to_workspace` is enabled in config and `path` resolves outside the workspace
- **THEN** it SHALL return `{:error, "Path <path> is outside allowed directory <workspace>"}`

### Requirement: Shared path resolution with tilde expansion and server-side workspace enforcement
All filesystem actions SHALL resolve paths using `Goodwizard.Actions.Filesystem.resolve_path/1` which expands `~` to the user's home directory and enforces workspace restrictions from `Goodwizard.Config` when `tools.restrict_to_workspace` is enabled. A `resolve_path/2` variant accepting an explicit allowed directory is available as an internal API (`@doc false`) for tests and programmatic use, but is NOT exposed in any action schema.

#### Scenario: Resolve path with tilde
- **WHEN** `resolve_path("~/foo/bar.txt")` is called
- **THEN** it SHALL return `{:ok, "/Users/<user>/foo/bar.txt"}` (fully expanded absolute path)

#### Scenario: Resolve path outside workspace
- **WHEN** `resolve_path("/etc/passwd")` is called and `tools.restrict_to_workspace` is enabled with workspace `/home/user/project/priv/workspace`
- **THEN** it SHALL return `{:error, "Path /etc/passwd is outside allowed directory /home/user/project/priv/workspace"}`

#### Scenario: Resolve path within workspace
- **WHEN** `resolve_path("priv/workspace/file.txt")` is called and `tools.restrict_to_workspace` is enabled
- **THEN** it SHALL return `{:ok, "<expanded path>"}` successfully

#### Scenario: No restriction when disabled
- **WHEN** `resolve_path("/any/path")` is called and `tools.restrict_to_workspace` is `false`
- **THEN** it SHALL return `{:ok, "<expanded path>"}` without workspace enforcement
