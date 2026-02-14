# Phase 7: Prompt Skills (Claude Code Compatible)

## Why

Prompt skills let users extend the agent's capabilities by dropping SKILL.md files into workspace directories. Goodwizard should scan, index, and surface these skills using the same frontmatter format and progressive disclosure model that Claude Code uses — so skills are portable between the two systems.

## What

### Goodwizard.Skills.PromptSkills (Jido Skill)

- State key: `:prompt_skills`
- On mount: scan `workspace/skills/` and `.claude/skills/` for SKILL.md files (workspace takes precedence on name collision)
- Parse Claude Code frontmatter (`name`, `description`, passthrough extra fields as `meta`)
- Index resource files (non-SKILL.md files in each skill directory)
- Cache SKILL.md body (frontmatter stripped) per skill
- Build plain-text skills summary for system prompt injection

### Goodwizard.Skills.PromptSkills.Parser (internal)

- `parse_frontmatter/1` — extract name, description, extra fields, and body from SKILL.md content
- `validate_metadata/1` — enforce name pattern (`^[a-z0-9-]+$`, max 64 chars) and description length (max 1024 chars)

### Goodwizard.Actions.Skills.ActivateSkill (Jido Action)

- Tool name: `activate_skill`
- Schema: `name: :string (required)`
- Returns full SKILL.md body for the named skill (Tier 2 content)

### Goodwizard.Actions.Skills.LoadSkillResource (Jido Action)

- Tool name: `load_skill_resource`
- Schema: `skill_name: :string (required)`, `resource: :string (required)`
- Reads a resource file from the skill's directory (Tier 3 content)
- Validates filename against indexed resource list to prevent path traversal

### Hydrator Integration

Skills are injected via `Hydrator.inject_skills/2`:
- Skills summary (name, description, resource filenames) added as an instruction via `Jido.Character.add_instruction/2`
- Activated skill content added as knowledge items with category "active-skill" via `Jido.Character.add_knowledge/3`
- Accept `:skills` option as a map (prompt_skills state) in `Hydrator.hydrate/2` opts

### Agent Updates

- Mount `PromptSkills` alongside Session and Memory
- Register `ActivateSkill` and `LoadSkillResource` in tools list
- Pass `state.prompt_skills` to Hydrator in `on_before_cmd/2` opts

## Dependencies

- Phase 6 (Memory + Persistence)

## Key Differences from Original Design

| Aspect | Original | Refactored |
|--------|----------|------------|
| Frontmatter | Custom (always, requirements) | Claude Code compatible (name, description only) |
| Loading model | Two-tier (always vs on-demand XML) | Three-tier progressive disclosure |
| Summary format | XML `<skills>` | Plain-text markdown |
| Scan dirs | `workspace/skills/` only | `workspace/skills/` + `.claude/skills/` |
| Actions | None (passive skill only) | `activate_skill` + `load_skill_resource` |
| Requirements | Loader checks bins/env | Skills handle own prereqs in instructions |
| Resources | Not tracked | Indexed and loadable via action |
