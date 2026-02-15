## ADDED Requirements

### Requirement: Setup task creates workspace directories
The `mix goodwizard.setup` task SHALL create the workspace directory structure at `priv/workspace/` with subdirectories `memory/`, `sessions/`, and `skills/`.

#### Scenario: First-time setup
- **WHEN** `mix goodwizard.setup` is run and `priv/workspace/` does not exist
- **THEN** the directories `priv/workspace/memory/`, `priv/workspace/sessions/`, and `priv/workspace/skills/` are created
- **THEN** a success message is printed for each created directory

#### Scenario: Setup with existing directories
- **WHEN** `mix goodwizard.setup` is run and some directories already exist
- **THEN** only missing directories are created
- **THEN** existing directories are not modified

### Requirement: Setup task writes default config
The `mix goodwizard.setup` task SHALL write a default `config.toml` to the project root (`config.toml`) if the file does not already exist.

#### Scenario: Default config created
- **WHEN** `mix goodwizard.setup` is run and `config.toml` does not exist in the project root
- **THEN** a default `config.toml` is written with workspace set to `"priv/workspace"`, model, and default settings

#### Scenario: Existing config preserved
- **WHEN** `mix goodwizard.setup` is run and `config.toml` already exists in the project root
- **THEN** the existing file is not overwritten
- **THEN** a message indicates the config already exists

### Requirement: CLI task starts the application and launches CLI channel
The `mix goodwizard.cli` task SHALL start the Goodwizard application, launch the CLI Server directly, and keep the process alive until the channel terminates.

#### Scenario: CLI task launches REPL
- **WHEN** `mix goodwizard.cli` is run
- **THEN** the Goodwizard application is started
- **THEN** a CLI Server is started directly (not via a supervisor helper)
- **THEN** the user sees the `"you> "` prompt

#### Scenario: CLI task exits when channel terminates
- **WHEN** the CLI channel process terminates (e.g., user sends EOF)
- **THEN** the mix task process exits cleanly
