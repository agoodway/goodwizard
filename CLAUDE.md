# Goodwizard Development Guide

## Action Context Limitation

Jido does NOT propagate `agent.state` into the action `context` map. Actions receive a context with `agent_id`, `call_id`, `action_metadata`, `iteration`, and `thread_id` — but no `:state` key.

**Do not** rely on `get_in(context, [:state, ...])` as the sole source for config values. Always provide a fallback:

- **Workspace path**: Use `Goodwizard.Actions.Brain.Helpers.workspace(context)` or fall back to `Goodwizard.Config.workspace()` directly.
- **Skills list**: Fall back to `Goodwizard.Plugins.PromptSkills.scan_skills(Goodwizard.Config.workspace())` when `context.state.prompt_skills.skills` is nil/empty.
- **General config**: Read from `Goodwizard.Config` module functions, not from agent state.

The `context.state` path may work in the future if Jido adds state propagation, so keep it as the preferred source with Config as fallback.

## Caching with Goodwizard.Cache

`Goodwizard.Cache` is a Nebulex local ETS cache started in the supervision tree (after Config, before Jido). Use it to avoid repeated filesystem reads on hot paths.

**When to use it:**

- Brain entity/schema reads that happen frequently within a session
- Skills list scans (`PromptSkills.scan_skills`) — the skill set rarely changes mid-session
- Session metadata lookups
- Any action that reads the same file-backed data multiple times per conversation turn

**API basics:**

```elixir
alias Goodwizard.Cache

Cache.put("brain:people:abc123", entity)           # store
Cache.get("brain:people:abc123")                    # fetch (nil on miss)
Cache.put("skills:list", skills, ttl: :timer.minutes(5))  # store with TTL
Cache.delete("brain:people:abc123")                 # invalidate
Cache.has_key?("brain:people:abc123")               # check existence
```

**Key conventions:** Use `"domain:type:id"` style keys (e.g. `"brain:people:abc123"`, `"skills:list"`, `"session:meta:cli"`).

**Invalidation:** Always invalidate or update the cache entry when writing/updating the underlying data. A stale cache is worse than no cache.

**TTL guidance:** Use TTLs for data that may change externally (skills, config). Omit TTL for data only modified through Goodwizard actions (brain entities) — invalidate explicitly on write instead.

## Upstream Dependency Source Code

When writing or debugging code that interacts with Jido libraries, read the source directly from these local checkouts rather than guessing at APIs:

- **Jido** (core agent framework): `/Users/tbrewer/projects/jido`
- **Jido AI** (LLM integration, ReAct loop, tool execution): `/Users/tbrewer/projects/jido_ai`
- **Jido Messaging** (rooms, messages, delivery): `/Users/tbrewer/projects/jido_messaging`

Use these to look up function signatures, struct definitions, behaviour callbacks, and module internals. Prefer reading the actual source over assumptions about how a Jido API works.

## Configuration Changes

When adding, removing, or renaming config options, update **all three** locations that define or reference them:

1. **`lib/goodwizard/config.ex`** — `@defaults` map (hardcoded fallback values)
2. **`config.toml`** — the project's live config file (add new options commented out with a description)
3. **`lib/mix/tasks/goodwizard.setup.ex`** — `@default_config` template (what `mix goodwizard.setup` generates for new projects)

If the option has an env var override, also update the `@env_overrides` list in `config.ex`.

## Project Structure

- `lib/goodwizard/actions/` — Jido actions (tools the agent can call)
- `lib/goodwizard/plugins/` — Jido plugins (mount into agent state at startup)
- `lib/goodwizard/channels/` — Channel handlers (CLI, Telegram)
- `lib/goodwizard/brain/` — Knowledge base (file-backed entity store)
- `lib/goodwizard/character/preamble.ex` — Code-controlled system prompt preamble (see Configuration Changes below)
- `lib/goodwizard/cache.ex` — Nebulex local ETS cache (see Caching section above)
- `lib/goodwizard/config.ex` — Config GenServer (TOML + env vars + defaults)
- `priv/workspace/` — Default workspace (brain data, skills, memory, sessions)

## Configuration Changes

When workspace structure changes (adding/removing directories or bootstrap files), update these locations:

- `lib/goodwizard/character/preamble.ex` — Update `generate/0` to reflect new directories or bootstrap files in the system prompt orientation text
- `test/goodwizard/character/preamble_test.exs` — Update test assertions to match the new directory/file names
