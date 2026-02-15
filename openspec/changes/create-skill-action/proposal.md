## Why

When the Goodwizard agent is asked to create a prompt skill, it has no dedicated action for it. It falls back to the generic `write_file` action and guesses the path — writing to `.claude/skills/` (Claude Code's skill directory) instead of the workspace `skills/` directory where Goodwizard agent skills belong. This results in skills being invisible to the agent at runtime.

## What Changes

- Add a new `Goodwizard.Actions.Skills.CreateSkill` action that writes a SKILL.md file to the correct workspace `skills/<skill-name>/` directory
- The action validates skill name format, generates proper frontmatter, ensures the skill directory structure, and writes the file
- Register the new action in the agent's tool list

## Capabilities

### New Capabilities
- `skill-creation`: A dedicated action for creating prompt skills scoped to the workspace skills directory, with name validation, frontmatter generation, and directory scaffolding

### Modified Capabilities
_None._

## Impact

- **Agent tools**: New `CreateSkill` action added to `Goodwizard.Agent` tool list
- **Filesystem**: Creates skill directories under `<workspace>/skills/`
- **Existing code**: No changes to `ActivateSkill`, `LoadSkillResource`, or `PromptSkills` plugin — purely additive
