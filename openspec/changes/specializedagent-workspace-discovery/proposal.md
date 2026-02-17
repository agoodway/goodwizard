## Why

Subagents are currently defined entirely in Elixir code — one hardcoded `SubAgent` module with a fixed character and tool list. To build an "AI workforce" of specialized agents, users need a way to define agent roles through workspace configuration files, not code changes. This mirrors how prompt skills already work: a directory per skill with a `SKILL.md` containing frontmatter + content.

Without a discovery mechanism, every new agent role requires modifying Elixir source, recompiling, and redeploying.

## What Changes

- Define a `workspace/specializedagents/<name>/` directory convention where each subdirectory represents a named specializedagent role.
- Define the `SUBAGENT.md` file format: YAML frontmatter (name, description, model, max_iterations, timeout, tool categories) + markdown body (system prompt / instructions).
- Add `Goodwizard.Plugins.Subagents` plugin that scans and indexes specializedagent configs at agent startup, modeled after `PromptSkills`.
- Cache discovered configs in `Goodwizard.Cache` with TTL.
- Ship two default specializedagent configs (`researcher`, `coder`) in `priv/workspace/specializedagents/`.
- Update `Mix.Tasks.Goodwizard.Setup` to create the `specializedagents/` directory and seed default specializedagent configs.

## Capabilities

### New Capabilities

- `specializedagent-workspace-discovery`: Discover and parse specializedagent role definitions from `workspace/specializedagents/` directories at agent startup.

### Modified Capabilities

_None — the existing SubAgent module and Spawn action are unchanged in this proposal._

## Impact

- **New files**: `lib/goodwizard/plugins/specializedagents.ex`, `lib/goodwizard/plugins/specializedagents/parser.ex`, `priv/workspace/specializedagents/researcher/SUBAGENT.md`, `priv/workspace/specializedagents/coder/SUBAGENT.md`
- **Modified files**: `lib/goodwizard/agent.ex` (add Subagents plugin to plugins list), `lib/mix/tasks/goodwizard.setup.ex` (add `specializedagents` to `@subdirs`, seed default SUBAGENT.md files per role)
- **Dependencies**: None new — uses existing PromptSkills patterns, Jido.Plugin, Goodwizard.Cache
