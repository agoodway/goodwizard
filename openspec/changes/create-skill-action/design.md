## Context

Goodwizard has a `PromptSkills` plugin that scans two directories for skills:
1. `<workspace>/skills/` — Goodwizard agent skills (for the agent at runtime)

The agent has `ActivateSkill` (read a skill's body) and `LoadSkillResource` (read a resource file) actions, but no action for *creating* skills. When asked to create a skill, the agent uses the generic `write_file` action and often writes to the wrong directory.

## Goals / Non-Goals

**Goals:**
- A dedicated `CreateSkill` action that always writes to `<workspace>/skills/<name>/SKILL.md`
- Validate skill name (kebab-case, no traversal)
- Generate proper SKILL.md frontmatter from structured params
- Create the skill directory if needed

**Non-Goals:**
- Updating or deleting existing skills (can use `edit_file`/filesystem actions)
- Managing resource files alongside skills (agent can use `write_file` into the skill dir after creation)
- Changing how `PromptSkills` plugin discovers or indexes skills

## Decisions

### 1. Action writes to workspace `skills/` directory only

The action resolves the workspace path from agent state (`state.workspace`) and always writes under `skills/<name>/SKILL.md`. It does not accept an arbitrary path — the directory is determined by the skill name.

**Rationale**: This is the whole point — prevent the agent from writing skills to the wrong location. The `.claude/skills/` directory is for Claude Code, not the agent.

**Alternative**: Accept a full path param — rejected because it defeats the purpose of scoping.

### 2. Params: name, description, content, and optional metadata

```
name:        string, required — kebab-case skill name (becomes directory name)
description: string, required — one-line description for skill summary
content:     string, required — the SKILL.md body (instructions)
metadata:    map, optional    — extra frontmatter fields (author, version, license, etc.)
```

The action assembles the SKILL.md with YAML frontmatter from name + description + metadata, then appends the content as the body.

**Rationale**: Matches the `Parser.parse_frontmatter` / `Parser.validate_metadata` contract — name and description are required fields, everything else goes in metadata.

### 3. Skill name validation

Names must be kebab-case: lowercase alphanumeric with hyphens, no leading/trailing hyphens, no consecutive hyphens. Reject names containing `..`, `/`, `\`, or null bytes.

**Rationale**: Name becomes a directory name. Must be filesystem-safe and consistent with existing skill naming conventions.

### 4. Overwrite protection

If a skill with the same name already exists, the action returns an error. The agent should use `edit_file` to modify existing skills.

**Rationale**: Prevents accidental overwrite of carefully crafted skills. Consistent with how `CreateEntity` in the brain system handles duplicates.

## Risks / Trade-offs

- **[No update action]** → Agent must use generic `edit_file` to modify skills after creation. Acceptable since updates are less common and the content is just markdown.
- **[No resource file creation]** → Agent must use `write_file` to add resource files to the skill directory. Acceptable since resources are optional and varied in format.
