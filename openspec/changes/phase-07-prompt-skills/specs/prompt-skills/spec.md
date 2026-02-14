## ADDED Requirements

### Requirement: Skill scanning finds SKILL.md files in both directories
The `Goodwizard.Skills.PromptSkills` module SHALL scan both `workspace/skills/` and `.claude/skills/` for subdirectories containing a `SKILL.md` file. Each subdirectory with a valid `SKILL.md` SHALL be treated as a discovered skill. Non-SKILL.md files in a skill directory SHALL be indexed as resources.

#### Scenario: Skills directory with multiple skills
- **WHEN** `workspace/skills/` contains subdirectories `search/SKILL.md` and `deploy/SKILL.md`, and `.claude/skills/` contains `edit/SKILL.md`
- **THEN** the scan SHALL return three discovered skills

#### Scenario: Workspace takes precedence on name collision
- **WHEN** both `workspace/skills/deploy/SKILL.md` and `.claude/skills/deploy/SKILL.md` exist
- **THEN** the scan SHALL use the workspace copy and ignore the `.claude/skills/` copy

#### Scenario: Neither skills directory exists
- **WHEN** the workspace has no `skills/` directory and no `.claude/skills/` directory
- **THEN** the scan SHALL return an empty list without error

#### Scenario: Empty skills directories
- **WHEN** both skill directories exist but contain no subdirectories with SKILL.md files
- **THEN** the scan SHALL return an empty list

#### Scenario: Subdirectory without SKILL.md is ignored
- **WHEN** a skills directory contains a subdirectory `drafts/` with no `SKILL.md`
- **THEN** that subdirectory SHALL be ignored in the scan results

#### Scenario: Resource files indexed per skill
- **WHEN** a skill directory `deploy/` contains `SKILL.md`, `deploy.sh`, and `config.template`
- **THEN** the discovered skill SHALL have resources `["config.template", "deploy.sh"]` (alphabetically sorted, excludes SKILL.md)

### Requirement: Frontmatter parsing extracts name and description
The `Goodwizard.Skills.PromptSkills.Parser` module SHALL parse YAML frontmatter from `SKILL.md` files, extracting `name` (string, required) and `description` (string, required). Any additional YAML fields SHALL be preserved in a `meta` map.

#### Scenario: Full frontmatter with extra fields
- **WHEN** a SKILL.md contains frontmatter with `name: "deploy"`, `description: "Deploy to production"`, `license: "MIT"`, and `metadata: {author: "user", version: "1.0"}`
- **THEN** `parse_frontmatter/1` SHALL return `{:ok, %{name: "deploy", description: "Deploy to production", meta: %{"license" => "MIT", "metadata" => %{"author" => "user", "version" => "1.0"}}}, body}`

#### Scenario: Minimal frontmatter with only required fields
- **WHEN** a SKILL.md contains frontmatter with only `name: "helper"` and `description: "A helper skill"`
- **THEN** `parse_frontmatter/1` SHALL return `{:ok, %{name: "helper", description: "A helper skill", meta: %{}}, body}`

#### Scenario: Missing required name field
- **WHEN** a SKILL.md contains frontmatter with `description: "A skill"` but no `name`
- **THEN** `parse_frontmatter/1` SHALL return `{:error, "missing required field: name"}`

#### Scenario: Missing required description field
- **WHEN** a SKILL.md contains frontmatter with `name: "test"` but no `description`
- **THEN** `parse_frontmatter/1` SHALL return `{:error, "missing required field: description"}`

#### Scenario: Malformed YAML frontmatter
- **WHEN** a SKILL.md contains invalid YAML between `---` delimiters
- **THEN** `parse_frontmatter/1` SHALL return `{:error, reason}` and the skill SHALL be skipped with a warning log during scanning

#### Scenario: No frontmatter present
- **WHEN** a SKILL.md has no `---` delimiters at the start
- **THEN** `parse_frontmatter/1` SHALL return `{:error, "no frontmatter found"}` and the skill SHALL be skipped with a warning log

### Requirement: Frontmatter stripped from skill content
The parser SHALL strip YAML frontmatter (everything between and including the `---` delimiters) from the skill content, returning only the markdown body.

#### Scenario: Content after frontmatter preserved
- **WHEN** a SKILL.md contains frontmatter followed by markdown content
- **THEN** the returned body SHALL contain only the markdown body without the frontmatter block

#### Scenario: Leading whitespace after frontmatter trimmed
- **WHEN** a SKILL.md has blank lines between the closing `---` and the content
- **THEN** the returned body SHALL have leading whitespace trimmed

#### Scenario: Body containing --- separators
- **WHEN** a SKILL.md has frontmatter followed by body content containing `---` as markdown section dividers
- **THEN** the parser SHALL treat only the first two `---` lines as frontmatter delimiters, preserving all subsequent `---` lines as body content

### Requirement: Name and description validation
The `Goodwizard.Skills.PromptSkills.Parser.validate_metadata/1` function SHALL enforce Claude Code naming constraints: `name` must match `^[a-z0-9-]+$` and be at most 64 characters; `description` must be at most 1024 characters.

#### Scenario: Valid name and description
- **WHEN** `validate_metadata/1` receives `%{name: "deploy-prod", description: "Deploy to production"}`
- **THEN** it SHALL return `{:ok, metadata}`

#### Scenario: Name exceeds max length
- **WHEN** `validate_metadata/1` receives a name longer than 64 characters
- **THEN** it SHALL return `{:error, "name must be at most 64 characters"}`

#### Scenario: Name contains invalid characters
- **WHEN** `validate_metadata/1` receives `%{name: "Deploy_Prod"}`
- **THEN** it SHALL return `{:error, "name must match ^[a-z0-9-]+$"}`

#### Scenario: Description exceeds max length
- **WHEN** `validate_metadata/1` receives a description longer than 1024 characters
- **THEN** it SHALL return `{:error, "description must be at most 1024 characters"}`

### Requirement: Skills summary in plain-text format
The module SHALL generate a plain-text markdown summary of all discovered skills. Each skill entry SHALL include its name (bold), description, and resource filenames (if any). The summary SHALL include a header instructing the LLM to use the `activate_skill` tool.

#### Scenario: Summary with skills and resources
- **WHEN** the workspace contains a skill "deploy" with resources `["deploy.sh", "config.template"]` and a skill "search" with no resources
- **THEN** the summary SHALL be:
  ```
  ## Available Skills

  Skills can be activated with the activate_skill tool when relevant.

  - **deploy** - Deploy application to production servers
    Resources: config.template, deploy.sh
  - **search** - Search the web for information
  ```

#### Scenario: No skills discovered
- **WHEN** no skills are discovered
- **THEN** `build_skills_summary/1` SHALL return an empty string

### Requirement: PromptSkills mounts on agent initialization
The `Goodwizard.Skills.PromptSkills` Jido Skill SHALL use `state_key: :prompt_skills`. On mount, it SHALL scan both skill directories, parse and validate each SKILL.md, index resources, cache stripped body content, and build the plain-text summary.

#### Scenario: Mount with populated skills directories
- **WHEN** the skill is mounted on an agent with `workspace: "/home/user/project"` and the workspace contains 3 skills across `skills/` and `.claude/skills/`
- **THEN** the state at `:prompt_skills` SHALL contain the skills list (with name, description, path, dir, content, resources, meta per skill) and the pre-rendered skills_summary

#### Scenario: Mount with empty workspace
- **WHEN** the skill is mounted on an agent with `workspace: "/home/user/project"` and no skills exist
- **THEN** the state at `:prompt_skills` SHALL contain an empty skills list and an empty skills_summary string

#### Scenario: Mount resolves scan directories from workspace
- **WHEN** the skill is mounted on an agent with `workspace: "/home/user/project"`
- **THEN** the skill SHALL scan `/home/user/project/skills/` and `/home/user/project/.claude/skills/` for SKILL.md files

#### Scenario: Mount skips invalid skills gracefully
- **WHEN** the skill directories contain 3 skill subdirectories but 1 has malformed frontmatter
- **THEN** the state SHALL contain 2 valid skills and the malformed skill SHALL be skipped with a warning log
