# Phase 7: Prompt Skills and Bootstrap Files

## Why

Prompt skills let users extend the agent's capabilities by dropping SKILL.md files into the workspace. Always-on skills inject their content into every system prompt, while on-demand skills are summarized so the agent knows they exist. This is the extensibility mechanism that makes Goodwizard customizable per user.

## What

### Goodwizard.Skills.PromptSkills (Jido Skill)

Port of `nanobot/agent/skills.py:SkillsLoader` (229 lines).

- State key: `:prompt_skills`
- Schema: workspace_skills_dir (string), always_skills (list of strings), skills_summary (string)
- On mount: scan workspace/skills/ for SKILL.md files

### Functions to Port

- `list_skills()` — Scan workspace/skills/ and builtin dirs for SKILL.md files
- `get_always_skills()` — Skills with `always: true` in frontmatter
- `load_skills_for_context()` — Load and strip frontmatter
- `build_skills_summary()` — XML summary with name, description, path, availability
- `_check_requirements()` — Verify required bins/env vars exist
- `_strip_frontmatter()` — Remove YAML frontmatter from markdown
- `_parse_nanobot_metadata()` — Parse JSON metadata from frontmatter

### ContextBuilder Updates

- Add `## Active Skills` section (always-loaded skills full content)
- Add `## Skills` section (summary of available on-demand skills)

## Dependencies

- Phase 6 (Memory + Persistence)

## Reference

- `nanobot/agent/skills.py` (229 lines)
