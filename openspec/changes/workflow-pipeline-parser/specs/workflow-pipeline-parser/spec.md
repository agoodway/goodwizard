## ADDED Requirements

### Requirement: Pipeline strings are split on unquoted pipe characters

The parser SHALL split an input string on the `|` character to identify individual step segments. Pipe characters inside single-quoted or double-quoted strings SHALL NOT be treated as delimiters.

#### Scenario: Simple two-step pipeline splits correctly

- **WHEN** the parser receives `"exec --shell 'ls' | approve --prompt 'ok?'"`
- **THEN** it produces a Pipeline with two steps in order

#### Scenario: Pipe inside quoted string is preserved

- **WHEN** the parser receives `"exec --shell 'echo hello | grep hello'"`
- **THEN** it produces a Pipeline with one step whose shell value is `echo hello | grep hello`

#### Scenario: Three-step pipeline preserves order

- **WHEN** the parser receives `"exec --shell 'cmd1' | exec --stdin json --shell 'cmd2' | approve --prompt 'ok?'"`
- **THEN** it produces a Pipeline with three steps in the exact order given

### Requirement: Quoted strings are tokenized correctly

The parser SHALL support both single-quoted and double-quoted string values. Quote delimiters SHALL be stripped from the resulting token value. Content between matching quote delimiters SHALL be preserved as a single token regardless of spaces.

#### Scenario: Single-quoted value with spaces

- **WHEN** the parser receives `"exec --shell 'inbox list --json'"`
- **THEN** the step's shell flag value is `inbox list --json`

#### Scenario: Double-quoted value with spaces

- **WHEN** the parser receives a step with a double-quoted flag value
- **THEN** the quotes are stripped and spaces within are preserved

#### Scenario: Unclosed quote produces an error

- **WHEN** the parser receives `"exec --shell 'unclosed"`
- **THEN** it returns `{:error, reason}` indicating an unclosed quote

### Requirement: Step types are recognized from the first token of each segment

The parser SHALL recognize `exec`, `approve`, and `openclaw.invoke` as valid step type keywords. An unrecognized step type SHALL produce an error.

#### Scenario: exec step type is recognized

- **WHEN** a pipe segment begins with `exec`
- **THEN** the resulting Step struct has type `:exec`

#### Scenario: approve step type is recognized

- **WHEN** a pipe segment begins with `approve`
- **THEN** the resulting Step struct has type `:approve`

#### Scenario: openclaw.invoke step type is recognized

- **WHEN** a pipe segment begins with `openclaw.invoke`
- **THEN** the resulting Step struct has type `:openclaw_invoke`

#### Scenario: Unknown step type produces an error

- **WHEN** a pipe segment begins with `unknown_cmd`
- **THEN** the parser returns `{:error, reason}` indicating an unrecognized step type

### Requirement: Flags are parsed as key-value or boolean pairs

The parser SHALL parse `--key value` pairs where the value is the next token. Boolean flags (`--preview-from-stdin`, `--each`) SHALL be recognized as standalone flags.

#### Scenario: --shell flag captures its value

- **WHEN** the parser encounters `exec --shell 'ls -la'`
- **THEN** the step's shell field is set to `ls -la`

#### Scenario: --stdin flag captures its value

- **WHEN** the parser encounters `exec --stdin json --shell 'cmd'`
- **THEN** the step's stdin field is set to `json`

#### Scenario: --prompt flag captures its value

- **WHEN** the parser encounters `approve --prompt 'Apply changes?'`
- **THEN** the step's prompt field is set to `Apply changes?`

#### Scenario: --preview-from-stdin is a boolean flag

- **WHEN** the parser encounters `approve --preview-from-stdin --prompt 'ok?'`
- **THEN** the step's preview_from_stdin is `true` and prompt is `ok?`

#### Scenario: --each is a boolean flag

- **WHEN** the parser encounters `exec --each --shell 'cmd'`
- **THEN** the step's each field is `true`

#### Scenario: Unknown flag produces an error

- **WHEN** the parser encounters `exec --nonexistent 'value'`
- **THEN** the parser returns `{:error, reason}`

### Requirement: Malformed input produces descriptive errors

The parser SHALL return `{:error, reason}` for all malformed inputs with a descriptive reason string.

#### Scenario: Empty string input

- **WHEN** the parser receives `""`
- **THEN** it returns `{:error, reason}` indicating empty input

#### Scenario: Whitespace-only input

- **WHEN** the parser receives `"   "`
- **THEN** it returns `{:error, reason}` indicating empty input

#### Scenario: Value flag at end of input with no value

- **WHEN** the parser receives `"exec --shell"`
- **THEN** it returns `{:error, reason}` indicating a missing value

### Requirement: Parse result is a Pipeline struct

The parser SHALL return `{:ok, %Pipeline{steps: steps}}` on success where steps is a list of Step structs in input order.

#### Scenario: Successful parse returns ok tuple with Pipeline

- **WHEN** the parser receives a valid pipeline string with two steps
- **THEN** it returns `{:ok, %Pipeline{steps: [%Step{}, %Step{}]}}`

#### Scenario: Single step pipeline is valid

- **WHEN** the parser receives `"exec --shell 'ls'"`
- **THEN** it returns `{:ok, %Pipeline{steps: [%Step{}]}}` with one Step
