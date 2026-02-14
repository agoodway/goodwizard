## MODIFIED Requirements

### Requirement: PromptSkills mounted alongside Session and Memory
The agent SHALL mount `Goodwizard.Skills.PromptSkills` as a Jido Skill in addition to Session (Phase 4) and Memory (Phase 6). The PromptSkills skill SHALL be mounted after Memory so that `state.workspace` is available for directory scanning.

#### Scenario: Agent initializes with all three skills
- **WHEN** an agent is started with `workspace: "/home/user/project"`
- **THEN** `state.prompt_skills` SHALL be populated with scanned skills data alongside `state.session` and `state.memory`

#### Scenario: PromptSkills mount does not affect other skills
- **WHEN** the PromptSkills skill is mounted
- **THEN** `state.session` and `state.memory` SHALL remain unchanged

### Requirement: System prompt includes skills context
The `on_before_cmd/2` callback SHALL pass `state.prompt_skills` to `ContextBuilder.build_system_prompt/2` via the `:skills` option, in addition to the existing `:memory` option from Phase 6.

#### Scenario: on_before_cmd passes both memory and skills
- **WHEN** `on_before_cmd/2` builds the system prompt
- **THEN** it SHALL call `ContextBuilder.build_system_prompt(workspace, memory: state.memory.long_term_content, skills: state.prompt_skills)`

#### Scenario: Skills not passed when PromptSkills state is empty
- **WHEN** `on_before_cmd/2` runs and `state.prompt_skills.skills` is an empty list
- **THEN** `build_system_prompt/2` SHALL still receive the `:skills` option (ContextBuilder handles omitting the section when no skills exist)

### Requirement: Skill actions registered as additional tools
The agent's tools list SHALL include `Goodwizard.Actions.Skills.ActivateSkill` and `Goodwizard.Actions.Skills.LoadSkillResource` alongside the existing filesystem (Phase 2), shell (Phase 2), and memory (Phase 6) actions.

#### Scenario: Complete tools list
- **WHEN** the agent is configured with all tools
- **THEN** `ToolAdapter.from_actions/1` SHALL produce 12 tool definitions: ReadFile, WriteFile, EditFile, ListDir, Exec, ReadLongTerm, WriteLongTerm, AppendHistory, SearchHistory, Consolidate, ActivateSkill, LoadSkillResource

#### Scenario: No tool name conflicts
- **WHEN** all 12 actions are registered
- **THEN** each tool definition SHALL have a unique name with no collisions
