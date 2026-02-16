## ADDED Requirements

### Requirement: Preamble module generates orientation text
The system SHALL provide a `Goodwizard.Character.Preamble` module with a `generate/0` function that returns a string describing the workspace directory layout and the purpose of each directory and bootstrap file.

#### Scenario: Generate returns a non-empty string
- **WHEN** `Preamble.generate/0` is called
- **THEN** it returns a non-empty binary string

#### Scenario: Output includes workspace directory descriptions
- **WHEN** `Preamble.generate/0` is called
- **THEN** the returned string MUST reference the following directories: `brain`, `memory`, `sessions`, `skills`, `scheduling`

#### Scenario: Output includes bootstrap file descriptions
- **WHEN** `Preamble.generate/0` is called
- **THEN** the returned string MUST reference the following files: `IDENTITY.md`, `SOUL.md`, `USER.md`, `TOOLS.md`, `AGENTS.md`

### Requirement: Preamble is injected at the start of the system prompt
The Hydrator SHALL prepend the preamble before the character-rendered content so it appears at the very top of the system prompt.

#### Scenario: Preamble appears before character content
- **WHEN** `Hydrator.hydrate/2` renders a system prompt
- **THEN** the returned string MUST start with the preamble content
- **THEN** the character-rendered content (identity, personality, etc.) MUST follow after the preamble

#### Scenario: Preamble is separated from character content
- **WHEN** `Hydrator.hydrate/2` renders a system prompt
- **THEN** there MUST be a blank line separating the preamble from the character content

### Requirement: Preamble is code-controlled and static
The preamble content SHALL be defined in code, not in workspace files or config. It MUST NOT be overridable via `config.toml` or workspace markdown files.

#### Scenario: Preamble is consistent across calls
- **WHEN** `Preamble.generate/0` is called multiple times
- **THEN** it MUST return the same string each time
