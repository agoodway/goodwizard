## ADDED Requirements

### Requirement: Memory skill state initialization
`Goodwizard.Skills.Memory` SHALL be a Jido Skill with `state_key: :memory` that initializes with the memory directory path and the contents of MEMORY.md when mounted.

#### Scenario: Mount initializes memory state from workspace
- **WHEN** the Memory skill is mounted on an agent with `workspace: "/home/user/project"`
- **THEN** the agent's state at key `:memory` contains `%{memory_dir: "/home/user/project", long_term_content: <contents_of_MEMORY.md>}`

#### Scenario: Mount with missing MEMORY.md
- **WHEN** the Memory skill is mounted and the workspace has no MEMORY.md file
- **THEN** the agent's state at key `:memory` contains `%{memory_dir: "/home/user/project", long_term_content: ""}`

#### Scenario: Mount resolves memory directory from workspace
- **WHEN** the Memory skill is mounted with `workspace: "~/myproject"`
- **THEN** `memory_dir` is set to the expanded absolute path of the workspace

### Requirement: Memory skill schema validation
The Memory skill schema SHALL define `memory_dir` as a required string and `long_term_content` as a string defaulting to empty.

#### Scenario: Schema rejects missing memory_dir
- **WHEN** the Memory skill is mounted without a workspace in agent state
- **THEN** mounting returns an error indicating memory_dir cannot be resolved

#### Scenario: Schema accepts valid configuration
- **WHEN** the Memory skill is mounted with a valid workspace path
- **THEN** mounting succeeds and returns the initialized state
