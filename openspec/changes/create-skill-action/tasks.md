## 1. Create Skill Action

- [x] 1.1 Create `Goodwizard.Actions.Skills.CreateSkill` action module with params: `name` (string, required), `description` (string, required), `content` (string, required), `metadata` (map, optional)
- [x] 1.2 Implement skill name validation — kebab-case regex, reject `..`, `/`, `\`, null bytes
- [x] 1.3 Implement SKILL.md frontmatter generation — assemble YAML frontmatter from name, description, and optional metadata, then append content as body
- [x] 1.4 Implement workspace path resolution — resolve workspace from agent context state, build path to `skills/<name>/SKILL.md`, create directories
- [x] 1.5 Implement overwrite protection — check if `SKILL.md` already exists in the skill directory, return error if so

## 2. Agent Registration

- [x] 2.1 Add `Goodwizard.Actions.Skills.CreateSkill` to the tools list in `Goodwizard.Agent`

## 3. Tests

- [x] 3.1 Write tests for `CreateSkill` — valid creation, frontmatter correctness, name validation (valid kebab-case, uppercase rejected, traversal rejected, slashes rejected), overwrite protection, missing required params, metadata inclusion
