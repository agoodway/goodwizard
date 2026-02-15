# Phase 7: Prompt Skills — Tasks

## Backend

- [x] 1.1 Create `Goodwizard.Skills.PromptSkills` skill (state_key `:prompt_skills`, mount scans `workspace/skills/`)
- [x] 1.2 Implement skill scanning — find SKILL.md files in `workspace/skills/`, list resource files per skill dir
- [x] 1.3 Implement `PromptSkills.Parser` — extract name + description, passthrough extra fields as meta, strip frontmatter from body (add `yaml_elixir` dependency)
- [x] 1.4 Implement name/description validation (name: max 64 chars, `^[a-z0-9-]+$`; description: max 1024 chars)
- [x] 1.5 Implement `build_skills_summary/1` — plain-text metadata list with resource filenames
- [x] 1.6 Create `ActivateSkill` action (lookup by name, return full SKILL.md body)
- [x] 1.7 Create `LoadSkillResource` action (read resource file, validate against indexed resource list)
- [x] 1.8 Update Hydrator — inject skills summary as instruction via `inject_skills/2`, accept `:skills` as map in hydrate/2 opts
- [x] 1.9 Register both actions in Agent tools list
- [x] 1.10 Mount PromptSkills on Agent, pass state to Hydrator in `on_before_cmd/2` opts

## Test

- [x] 2.1 Scanning finds SKILL.md files in `workspace/skills/`, lists resources
- [x] 2.2 Frontmatter parsing extracts name + description, preserves extra fields as meta, rejects missing required fields
- [x] 2.3 Name validation enforces max length and pattern
- [x] 2.4 Malformed frontmatter skipped with warning
- [x] 2.5 Summary plain-text format with resource listings
- [x] 2.6 ActivateSkill returns body for valid name, error for unknown
- [x] 2.7 LoadSkillResource reads valid file, rejects unlisted filenames
- [x] 2.8 Hydrator includes skills summary as instruction and active skill content as knowledge when skills provided
