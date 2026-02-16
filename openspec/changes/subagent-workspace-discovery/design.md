## Context

Prompt skills are discovered from `workspace/skills/<name>/SKILL.md` by the `PromptSkills` plugin at agent startup. Each skill has YAML frontmatter for metadata and markdown body for content. This pattern works well and is the model for subagent discovery.

The current `SubAgent` module has a hardcoded character (`SubAgent.Character`) and a fixed tool list. There is no mechanism to define specialized agent roles without writing Elixir code.

## Goals / Non-Goals

**Goals:**
- Define a workspace-based convention for subagent role configs
- Build a plugin that discovers and indexes configs on startup
- Ship useful default roles to demonstrate the pattern

**Non-Goals:**
- Wiring configs into the SubAgent runtime (covered by `subagent-configurable-spawn`)
- Changing how the Spawn action works
- Hot-reloading configs during a conversation

## Decisions

### 1. One directory per subagent role with a SUBAGENT.md file

**Choice**: `workspace/subagents/<name>/SUBAGENT.md` — same pattern as skills.

**Rationale**: Consistent with existing `workspace/skills/<name>/SKILL.md` convention. Users already understand this pattern. The directory allows additional resource files (reference docs, example outputs) alongside the config.

**Alternative considered**: A single `subagents.toml` config file listing all roles. Rejected because it doesn't scale well for complex system prompts and prevents per-agent resource files.

### 2. YAML frontmatter for config, markdown body for system prompt

**Choice**: Frontmatter schema:

```yaml
---
name: researcher
description: "Research agent for web and file-based investigation"
model: anthropic:claude-sonnet-4-5
max_iterations: 15
timeout: 180000
tools:
  - filesystem
  - shell
  - brain
---
```

Body is the system prompt / instructions injected into the agent's character.

**Rationale**: Matches SKILL.md format. YAML frontmatter is already parsed by `PromptSkills.Parser`. The body doubles as both human-readable documentation and machine-consumed system prompt.

### 3. Tool categories instead of module names

**Choice**: The `tools` frontmatter field uses category names (`filesystem`, `shell`, `brain`, `memory`, `messaging`, `scheduling`, `browser`) rather than module paths.

**Rationale**: Workspace configs should be user-editable without knowledge of Elixir module naming. Categories map to tool groups that the Spawn action resolves at runtime.

**Alternative considered**: Listing individual tool names (`read_file`, `write_file`). Rejected as too granular for config — categories are the right abstraction level for role definition.

### 4. Plugin modeled after PromptSkills

**Choice**: New `Goodwizard.Plugins.Subagents` with `state_key: :subagents` that scans on mount.

**Rationale**: Follows established plugin pattern. State is available via `agent.state.subagents` for the Spawn action to use (in the follow-up proposal).

## Risks / Trade-offs

- **Discovery at startup only** — New subagent configs require agent restart to be discovered. Acceptable for now; hot-reload can be added later via a refresh action (like `RefreshTools` for brain schemas).

### 5. Default roles seeded by `mix goodwizard.setup`

**Choice**: Add `subagents` to the setup task's `@subdirs` list so the directory is created alongside `memory`, `sessions`, and `skills`. Seed default `SUBAGENT.md` files for each role using the existing `seed_file` pattern, writing into `subagents/<role>/SUBAGENT.md` (skip if already exists).

**Rationale**: Follows established setup convention — brain schemas, bootstrap files, and directory structure are all created by the setup task. Users running `mix goodwizard.setup` on a fresh workspace should get working subagent roles out of the box without manual file creation.
