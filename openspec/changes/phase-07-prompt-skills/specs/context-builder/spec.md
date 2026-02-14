## MODIFIED Requirements

### Requirement: System prompt includes available skills section
The `Goodwizard.ContextBuilder.build_system_prompt/2` function SHALL accept a `:skills` option as a map containing the prompt_skills state (with keys `:skills` and `:skills_summary`). When skills are present, it SHALL include the pre-rendered plain-text "Available Skills" section in the system prompt.

#### Scenario: Skills present with summary
- **WHEN** `build_system_prompt(workspace, skills: %{skills: [%{name: "deploy", ...}, %{name: "search", ...}], skills_summary: "## Available Skills\n..."})` is called
- **THEN** the system prompt SHALL include the skills_summary content as-is

#### Scenario: No skills discovered
- **WHEN** the skills state contains an empty skills list and an empty skills_summary string
- **THEN** the system prompt SHALL omit the Available Skills section entirely

#### Scenario: Skills option not provided
- **WHEN** `build_system_prompt(workspace, [])` is called without a `:skills` option
- **THEN** the system prompt SHALL omit the Available Skills section (backward compatible with pre-Phase 7 callers)

#### Scenario: Available Skills section follows memory context
- **WHEN** both memory context and skills are provided
- **THEN** the Available Skills section SHALL appear after the memory context section in the system prompt

#### Scenario: Skills state accepted as map instead of string
- **WHEN** the `:skills` option is a map (prompt_skills state)
- **THEN** `build_system_prompt/2` SHALL extract the `:skills_summary` value from the map to render the section (replacing the prior behavior of accepting a pre-formatted string)

#### Scenario: Skills option passed as string raises error
- **WHEN** `build_system_prompt(workspace, skills: "some string")` is called with `:skills` as a string
- **THEN** `build_system_prompt/2` SHALL raise an `ArgumentError` indicating that `:skills` must be a map (the Phase 3 string format is superseded)
