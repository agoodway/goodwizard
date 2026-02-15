# Goodwizard Development Guide

## Action Context Limitation

Jido does NOT propagate `agent.state` into the action `context` map. Actions receive a context with `agent_id`, `call_id`, `action_metadata`, `iteration`, and `thread_id` — but no `:state` key.

**Do not** rely on `get_in(context, [:state, ...])` as the sole source for config values. Always provide a fallback:

- **Workspace path**: Use `Goodwizard.Actions.Brain.Helpers.workspace(context)` or fall back to `Goodwizard.Config.workspace()` directly.
- **Skills list**: Fall back to `Goodwizard.Plugins.PromptSkills.scan_skills(Goodwizard.Config.workspace())` when `context.state.prompt_skills.skills` is nil/empty.
- **General config**: Read from `Goodwizard.Config` module functions, not from agent state.

The `context.state` path may work in the future if Jido adds state propagation, so keep it as the preferred source with Config as fallback.

## Project Structure

- `lib/goodwizard/actions/` — Jido actions (tools the agent can call)
- `lib/goodwizard/plugins/` — Jido plugins (mount into agent state at startup)
- `lib/goodwizard/channels/` — Channel handlers (CLI, Telegram)
- `lib/goodwizard/brain/` — Knowledge base (file-backed entity store)
- `lib/goodwizard/config.ex` — Config GenServer (TOML + env vars + defaults)
- `priv/workspace/` — Default workspace (brain data, skills, memory, sessions)
