## Context

Phase 7 adds the workspace extensibility layer — prompt skills. The original design used a custom two-tier model (`always` vs on-demand with XML summary) that diverged from Claude Code's official skill format. This refactored design aligns Goodwizard's skill system with Claude Code's three-tier progressive disclosure model so skills are portable between the two systems.

In Goodwizard, `Goodwizard.Skills.PromptSkills` is a Jido Skill that scans workspace skill directories on mount, parses Claude Code-compatible SKILL.md frontmatter, indexes resource files, and provides skill metadata to `Goodwizard.ContextBuilder` (Phase 3). Two new Jido Actions — `ActivateSkill` and `LoadSkillResource` — let the LLM load skill content and resources on demand.

Phase 6 (Memory + Persistence) must be complete. The ContextBuilder already has placeholder hooks for `:skills` — Phase 7 wires real data into those hooks.

## Goals / Non-Goals

**Goals:**
- `Goodwizard.Skills.PromptSkills` Jido Skill that scans both `workspace/skills/` and `.claude/skills/`
- Claude Code-compatible frontmatter parsing (`name` + `description` required, extra fields as passthrough `meta`)
- Name and description validation matching Claude Code constraints
- Plain-text skills summary for system prompt injection (~20 tokens/skill)
- `ActivateSkill` action for on-demand Tier 2 content loading
- `LoadSkillResource` action for on-demand Tier 3 resource loading
- ContextBuilder integration: single "Available Skills" section with plain-text metadata

**Non-Goals:**
- Skill execution or invocation (skills are prompt content, not executable code)
- Remote skill registries or installation workflows
- Skill versioning or dependency resolution
- Hot-reloading skills during a conversation (re-scanned on next mount)
- Skill authoring tools or validation CLI
- Runtime requirement checking (skills handle own prereqs in their instructions)
- Always-on skill injection (content that must be in every prompt belongs in bootstrap files)

## Decisions

### 1. Adopt Claude Code frontmatter exactly

**Decision**: Only `name` (required, max 64 chars, lowercase + numbers + hyphens, `^[a-z0-9-]+$`) and `description` (required, max 1024 chars) are behavioral fields. Any extra YAML fields are preserved as passthrough `meta` but have no effect on loading behavior.

**Rationale**: Claude Code's SKILL.md format is the de facto standard for AI-assisted skill files. Using the same format means skills authored for Claude Code work in Goodwizard and vice versa. The existing `.claude/skills/` directory in the workspace already contains skills in this format (e.g., `openspec-explore`, `openspec-new-change`).

**Alternatives considered**: Custom frontmatter with `always`, `requirements.bins`, `requirements.env` fields (original design — creates a proprietary format that fragments the skill ecosystem).

### 2. Drop `always` flag — no always-on skills

**Decision**: Remove the `always: true` concept entirely. No skills are automatically injected into the system prompt. Only Tier 1 metadata (name + description, ~20 tokens/skill) appears in every prompt.

**Rationale**: Content that must be in every prompt belongs in bootstrap files (`AGENTS.md`, `SOUL.md`, etc.) which ContextBuilder already loads every turn. The `always` flag was a workaround for not having a proper bootstrap file system. With Phase 3's ContextBuilder loading bootstrap files, always-on skills are redundant and waste tokens.

**Alternatives considered**: Keep `always` as a Goodwizard extension (creates non-portable skills, token budget risk from large always-on content).

### 3. Drop `requirements` checking

**Decision**: Remove the `requirements.bins` and `requirements.env` checking. Skills handle their own prerequisites in their instruction body. The LLM checks requirements at runtime rather than the loader hiding skills.

**Rationale**: Claude Code doesn't have a requirements system. A skill that needs `curl` can say "This skill requires curl" in its instructions — the LLM will check at activation time, which is more flexible and doesn't hide skills from the summary unnecessarily. This also removes the need for `System.find_executable/1` calls during scanning.

**Alternatives considered**: Keep requirements as a Goodwizard extension with `available` flag (adds complexity, hides skills from summary, not portable).

### 4. Three-tier progressive disclosure

**Decision**: Replace the two-tier model (always + XML summary) with three tiers:
- **Tier 1 (Metadata)**: name + description in system prompt every turn (~20 tokens/skill)
- **Tier 2 (Instructions)**: full SKILL.md body loaded on-demand via `activate_skill` action
- **Tier 3 (Resources)**: bundled files (scripts, templates, extra .md) loaded via `load_skill_resource` action

**Rationale**: This matches Claude Code's progressive disclosure model. Tier 1 is cheap enough to always include. Tier 2 loads only when the LLM determines a skill is relevant. Tier 3 loads individual resource files only when the skill's instructions reference them. This minimizes token usage while giving the LLM full access to everything.

**Alternatives considered**: Two-tier with XML (original design — no resource loading, XML format less natural in markdown prompts), single-tier full injection (token-expensive for workspaces with many skills).

### 5. Plain-text summary replaces XML

**Decision**: The skills summary in the system prompt uses plain-text markdown format instead of XML:

```
## Available Skills

Skills can be activated with the activate_skill tool when relevant.

- **deploy** - Deploy application to production servers
  Resources: deploy.sh, config.template
- **search** - Search the web for information
```

**Rationale**: Plain text is more natural within a markdown-based system prompt. The XML format (`<skills><skill><name>...</name></skill></skills>`) adds structural overhead without benefit — the LLM doesn't need XML to understand a list. The resource filenames are included so the LLM knows what's available before activating.

**Alternatives considered**: XML format (original design — verbose, unnatural in markdown context), JSON (machine-readable but wasteful in prompt context).

### 6. Dual directory scanning with workspace precedence

**Decision**: Scan both `workspace/skills/` and `.claude/skills/` for SKILL.md files. On name collision, the workspace copy takes precedence.

**Rationale**: `.claude/skills/` is the standard Claude Code location. `workspace/skills/` is the Goodwizard convention. Scanning both ensures compatibility with both ecosystems. Workspace precedence allows project-specific overrides of shared skills.

**Alternatives considered**: Only scan `.claude/skills/` (breaks Goodwizard convention), only scan `workspace/skills/` (misses Claude Code skills), merge on collision (complex, ambiguous behavior).

## Risks / Trade-offs

**[yaml_elixir dependency]** → Adding `yaml_elixir` for frontmatter parsing introduces a new dependency. Mitigation: it's a well-maintained, widely-used Elixir library with minimal transitive deps.

**[Many skills consuming metadata budget]** → With ~20 tokens per skill in Tier 1, a workspace with 50 skills would use ~1000 tokens in every system prompt. Mitigation: this is acceptable overhead; workspaces rarely have that many skills. If needed, a future pagination mechanism could limit Tier 1 entries.

**[Missing skill directories]** → If neither `workspace/skills/` nor `.claude/skills/` exists, the scan should gracefully return an empty list. Mitigation: check directory existence before listing, return `[]` if absent.

**[Frontmatter encoding edge cases]** → SKILL.md files with non-UTF-8 encoding or malformed YAML frontmatter could cause parse errors. Mitigation: wrap parsing in try/rescue, skip malformed skills with a warning log, and continue scanning remaining files.

**[Path traversal in resource loading]** → The `load_skill_resource` action must prevent `../../etc/passwd` style attacks. Mitigation: validate the requested filename against the pre-indexed resource list (built at mount time) rather than constructing paths from user input.

**[Extra frontmatter fields]** → Claude Code skills in `.claude/skills/` contain extra fields like `license`, `compatibility`, `metadata.author`, `metadata.version`. Mitigation: these are preserved as passthrough `meta` — no validation applied, no behavioral effect. This ensures forward compatibility with future Claude Code frontmatter extensions.
