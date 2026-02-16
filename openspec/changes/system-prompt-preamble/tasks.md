## 1. Preamble Module

- [ ] 1.1 Create `lib/goodwizard/character/preamble.ex` with `generate/0` that returns the orientation string covering workspace directories (brain, memory, sessions, skills, scheduling) and bootstrap files (IDENTITY.md, SOUL.md, USER.md, TOOLS.md, AGENTS.md)
- [ ] 1.2 Write tests for `Preamble.generate/0`: returns non-empty string, includes all directory names, includes all bootstrap file names, returns same value on repeated calls

## 2. Hydrator Integration

- [ ] 2.1 Modify `Hydrator.hydrate/2` to prepend `Preamble.generate/0` output before the character-rendered string with a blank line separator
- [ ] 2.2 Update existing Hydrator tests to verify the system prompt starts with the preamble content

## 3. Documentation

- [ ] 3.1 Add `Preamble` module to the CLAUDE.md "Configuration Changes" section as a location to update when workspace structure changes
