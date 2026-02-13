# Phase 7: Prompt Skills — Tasks

## Backend

- [ ] 1.1 Create Goodwizard.Skills.PromptSkills skill (state_key :prompt_skills, mount scans workspace/skills/)
- [ ] 1.2 Implement skill scanning — find SKILL.md files in workspace/skills/ subdirectories
- [ ] 1.3 Implement frontmatter parsing — extract metadata (always flag, requirements, description) and strip from content
- [ ] 1.4 Implement requirements checking — verify required bins/env vars exist, mark skills as available/unavailable
- [ ] 1.5 Implement build_skills_summary — XML summary with name, description, path, availability
- [ ] 1.6 Update ContextBuilder — add Active Skills section (full content) and Skills section (summary)

## Test

- [ ] 2.1 Test scanning skills directory finds SKILL.md files
- [ ] 2.2 Test frontmatter parsing extracts metadata correctly
- [ ] 2.3 Test always skills loaded into context
- [ ] 2.4 Test requirements checking (missing binary marks skill unavailable)
- [ ] 2.5 Test skills summary XML format
