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

## Project Structure

- `lib/goodwizard/actions/` — Jido actions (tools the agent can call)
- `lib/goodwizard/plugins/` — Jido plugins (mount into agent state at startup)
- `lib/goodwizard/channels/` — Channel handlers (CLI, Telegram)
- `lib/goodwizard/brain/` — Knowledge base (file-backed entity store)
- `lib/goodwizard/cache.ex` — Nebulex local ETS cache (see Caching section above)
- `lib/goodwizard/config.ex` — Config GenServer (TOML + env vars + defaults)
- `priv/workspace/` — Default workspace (brain data, skills, memory, sessions)
