## ADDED Requirements

### Requirement: Create skill writes to workspace skills directory
The `create_skill` action SHALL write the skill's `SKILL.md` file to `<workspace>/skills/<name>/SKILL.md`. The workspace path SHALL be resolved from the agent's state.

#### Scenario: Skill created in correct directory
- **WHEN** the agent calls `create_skill` with name "my-tool"
- **THEN** the file SHALL be written to `<workspace>/skills/my-tool/SKILL.md`
- **THEN** the skill directory `<workspace>/skills/my-tool/` SHALL be created if it does not exist

#### Scenario: Workspace skills directory auto-created
- **WHEN** the `<workspace>/skills/` directory does not exist
- **THEN** the action SHALL create it before writing the skill file

### Requirement: Skill name validation
The action SHALL validate the skill name is kebab-case: lowercase alphanumeric characters and hyphens only, no leading or trailing hyphens, no consecutive hyphens. Names containing `..`, `/`, `\`, or null bytes SHALL be rejected.

#### Scenario: Valid kebab-case name accepted
- **WHEN** the agent calls `create_skill` with name "my-cool-tool"
- **THEN** the action SHALL accept the name and create the skill

#### Scenario: Invalid name with path traversal rejected
- **WHEN** the agent calls `create_skill` with name "../evil-skill"
- **THEN** the action SHALL return an error indicating invalid skill name
- **THEN** no file SHALL be written

#### Scenario: Invalid name with uppercase rejected
- **WHEN** the agent calls `create_skill` with name "MySkill"
- **THEN** the action SHALL return an error indicating the name must be kebab-case

#### Scenario: Invalid name with slashes rejected
- **WHEN** the agent calls `create_skill` with name "skills/nested"
- **THEN** the action SHALL return an error indicating invalid skill name

### Requirement: SKILL.md frontmatter generation
The action SHALL generate a SKILL.md file with YAML frontmatter containing `name` and `description` fields, plus any additional metadata fields provided. The body of the file SHALL be the provided content.

#### Scenario: Frontmatter with required fields
- **WHEN** the agent calls `create_skill` with name "my-tool", description "Does cool things", and content "Use this tool when..."
- **THEN** the generated SKILL.md SHALL have YAML frontmatter with `name: my-tool` and `description: Does cool things`
- **THEN** the file body after the closing `---` SHALL contain "Use this tool when..."

#### Scenario: Frontmatter with optional metadata
- **WHEN** the agent calls `create_skill` with metadata `%{"author" => "goodwizard", "version" => "1.0"}`
- **THEN** the frontmatter SHALL include `author: goodwizard` and `version: "1.0"` under a `metadata` key

### Requirement: Overwrite protection
The action SHALL NOT overwrite an existing skill. If a skill directory with the given name already exists and contains a SKILL.md file, the action SHALL return an error.

#### Scenario: Duplicate skill name rejected
- **WHEN** the agent calls `create_skill` with name "existing-skill" and a skill at `<workspace>/skills/existing-skill/SKILL.md` already exists
- **THEN** the action SHALL return an error indicating the skill already exists

### Requirement: Action registered in agent tools
The `CreateSkill` action SHALL be registered in the `Goodwizard.Agent` tool list so it is available during agent reasoning.

#### Scenario: Agent can invoke create_skill
- **WHEN** the agent is initialized
- **THEN** `Goodwizard.Actions.Skills.CreateSkill` SHALL be in the agent's tool list

### Requirement: Action requires name, description, and content
The action SHALL require `name` (string), `description` (string), and `content` (string) parameters. The `metadata` parameter (map) SHALL be optional.

#### Scenario: Missing required param returns error
- **WHEN** the agent calls `create_skill` without a `description` param
- **THEN** the action SHALL return a validation error indicating the missing field

#### Scenario: All required params provided succeeds
- **WHEN** the agent calls `create_skill` with name, description, and content
- **THEN** the action SHALL create the skill and return success with the skill's file path
