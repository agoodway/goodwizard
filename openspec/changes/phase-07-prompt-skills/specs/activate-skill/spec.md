## ADDED Requirements

### Requirement: ActivateSkill action returns skill body
The `Goodwizard.Actions.Skills.ActivateSkill` Jido Action SHALL be registered with tool name `activate_skill`. It SHALL accept a required `name` parameter (string) and return the full SKILL.md body (frontmatter stripped) for the named skill.

#### Scenario: Activate existing skill
- **WHEN** `activate_skill` is called with `name: "deploy"` and "deploy" is a discovered skill
- **THEN** the action SHALL return `{:ok, %{content: "<full SKILL.md body>"}}`

#### Scenario: Activate unknown skill
- **WHEN** `activate_skill` is called with `name: "nonexistent"`
- **THEN** the action SHALL return `{:error, "skill not found: nonexistent"}`

#### Scenario: Action schema validates name parameter
- **WHEN** `activate_skill` is called without a `name` parameter
- **THEN** the action SHALL return a schema validation error

### Requirement: ActivateSkill registered as agent tool
The `ActivateSkill` action SHALL be included in the agent's tools list alongside filesystem, shell, and memory actions. Its tool definition SHALL include a description that explains it loads a skill's full instructions for the current conversation.

#### Scenario: Tool definition format
- **WHEN** `ToolAdapter.from_actions/1` processes `ActivateSkill`
- **THEN** the tool definition SHALL have name `"activate_skill"`, a description mentioning loading skill instructions, and a parameter schema requiring `name` as a string
