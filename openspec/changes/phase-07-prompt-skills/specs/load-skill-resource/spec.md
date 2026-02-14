## ADDED Requirements

### Requirement: LoadSkillResource action reads resource files
The `Goodwizard.Actions.Skills.LoadSkillResource` Jido Action SHALL be registered with tool name `load_skill_resource`. It SHALL accept required `skill_name` (string) and `resource` (string) parameters, and return the contents of the requested resource file from the skill's directory.

#### Scenario: Load valid resource
- **WHEN** `load_skill_resource` is called with `skill_name: "deploy"` and `resource: "deploy.sh"`, and "deploy.sh" is in the skill's indexed resources
- **THEN** the action SHALL return `{:ok, %{content: "<file contents>", filename: "deploy.sh"}}`

#### Scenario: Resource not in indexed list
- **WHEN** `load_skill_resource` is called with `resource: "secret.env"` and that filename is not in the skill's indexed resources
- **THEN** the action SHALL return `{:error, "resource not found: secret.env"}`

#### Scenario: Unknown skill name
- **WHEN** `load_skill_resource` is called with `skill_name: "nonexistent"`
- **THEN** the action SHALL return `{:error, "skill not found: nonexistent"}`

#### Scenario: Path traversal prevented
- **WHEN** `load_skill_resource` is called with `resource: "../../etc/passwd"`
- **THEN** the action SHALL return `{:error, "resource not found: ../../etc/passwd"}` because the filename does not match any indexed resource

#### Scenario: Action schema validates parameters
- **WHEN** `load_skill_resource` is called without `skill_name` or `resource`
- **THEN** the action SHALL return a schema validation error

### Requirement: LoadSkillResource registered as agent tool
The `LoadSkillResource` action SHALL be included in the agent's tools list. Its tool definition SHALL include a description that explains it loads a bundled resource file from a skill's directory.

#### Scenario: Tool definition format
- **WHEN** `ToolAdapter.from_actions/1` processes `LoadSkillResource`
- **THEN** the tool definition SHALL have name `"load_skill_resource"`, a description mentioning loading skill resource files, and a parameter schema requiring `skill_name` and `resource` as strings
