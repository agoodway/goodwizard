## ADDED Requirements

### Requirement: Exec action executes shell commands
The `Goodwizard.Actions.Shell.Exec` action SHALL use `use Jido.Action` with a schema accepting `command` (required, string), `working_dir` (optional, string), `timeout` (optional, integer, default 60), `deny_patterns` (optional, list of strings), `allow_patterns` (optional, list of strings), and `restrict_to_workspace` (optional, boolean, default false). The `run/2` callback SHALL execute the command in a shell subprocess, capture stdout and stderr, and return the combined output.

#### Scenario: Execute a simple command
- **WHEN** `Exec` is called with `command: "echo hello"`
- **THEN** it SHALL return `{:ok, %{output: "hello\n"}}` with the stdout content

#### Scenario: Command produces stderr
- **WHEN** a command writes to stderr
- **THEN** the output SHALL include stderr prefixed with `"STDERR:\n"` after stdout

#### Scenario: Command exits with non-zero code
- **WHEN** a command exits with a non-zero return code
- **THEN** the output SHALL append `"\nExit code: <code>"` to the result

#### Scenario: Command produces no output
- **WHEN** a command produces neither stdout nor stderr
- **THEN** it SHALL return `{:ok, %{output: "(no output)"}}`

### Requirement: Exec enforces timeout
The Exec action SHALL kill commands that exceed the configured timeout.

#### Scenario: Command exceeds timeout
- **WHEN** `Exec` is called with `timeout: 2` and the command runs for longer than 2 seconds
- **THEN** it SHALL kill the process and return `{:error, "Command timed out after 2 seconds"}`

#### Scenario: Command completes within timeout
- **WHEN** a command completes before the timeout
- **THEN** it SHALL return the output normally

### Requirement: Exec blocks dangerous commands via deny patterns
The Exec action SHALL check the command against a list of regex deny patterns before execution. The default deny list SHALL include patterns for: `rm -rf`/`rm -r`/`rm -fr`, `del /f`/`del /q`, `rmdir /s`, `format`/`mkfs`/`diskpart`, `dd if=`, writes to `/dev/sd*`, `shutdown`/`reboot`/`poweroff`, and fork bombs.

#### Scenario: Command matches deny pattern
- **WHEN** `Exec` is called with `command: "rm -rf /"`
- **THEN** it SHALL return `{:error, "Command blocked by safety guard (dangerous pattern detected)"}` without executing

#### Scenario: Command does not match any deny pattern
- **WHEN** `Exec` is called with `command: "ls -la"`
- **THEN** the command SHALL proceed to execution

#### Scenario: Custom deny patterns override defaults
- **WHEN** `Exec` is called with a custom `deny_patterns` list
- **THEN** the custom list SHALL be used instead of the defaults

### Requirement: Exec supports allow-list mode
When `allow_patterns` is provided and non-empty, the Exec action SHALL only execute commands matching at least one allow pattern.

#### Scenario: Command matches allow pattern
- **WHEN** `allow_patterns` includes `"^git "` and `command` is `"git status"`
- **THEN** the command SHALL proceed to execution

#### Scenario: Command does not match any allow pattern
- **WHEN** `allow_patterns` is non-empty and no pattern matches the command
- **THEN** it SHALL return `{:error, "Command blocked by safety guard (not in allowlist)"}`

### Requirement: Exec restricts workspace paths
When `restrict_to_workspace` is true, the Exec action SHALL block commands containing path traversal (`../`) or absolute paths outside the working directory.

#### Scenario: Command contains path traversal
- **WHEN** `restrict_to_workspace` is true and the command contains `"../"`
- **THEN** it SHALL return `{:error, "Command blocked by safety guard (path traversal detected)"}`

#### Scenario: Command references path outside working directory
- **WHEN** `restrict_to_workspace` is true and the command contains an absolute path outside `working_dir`
- **THEN** it SHALL return `{:error, "Command blocked by safety guard (path outside working dir)"}`

#### Scenario: Command uses paths within working directory
- **WHEN** `restrict_to_workspace` is true and all paths in the command are within `working_dir`
- **THEN** the command SHALL proceed to execution

### Requirement: Exec truncates long output
The Exec action SHALL truncate combined output exceeding 10,000 characters.

#### Scenario: Output exceeds 10,000 characters
- **WHEN** a command produces more than 10,000 characters of output
- **THEN** the output SHALL be truncated at 10,000 characters with a suffix: `"\n... (truncated, <N> more chars)"`

#### Scenario: Output within limit
- **WHEN** a command produces fewer than 10,000 characters
- **THEN** the full output SHALL be returned
