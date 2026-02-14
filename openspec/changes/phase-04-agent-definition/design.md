## Context

Goodwizard is a personal AI coding assistant built on jido v2 and jido_ai. Phases 1–3 establish the foundation: project scaffold with Config GenServer, five Jido Actions (ReadFile, WriteFile, EditFile, ListDir, Exec), and ReAct integration via ContextBuilder and ToolAdapter. Phase 4 wires these into a single agent entity using jido_ai's `ReActAgent` macro, and adds in-memory session tracking for conversation history.

The `ReActAgent` macro generates the ask/await API, ReAct strategy wiring, and lifecycle hooks — so Phase 4 is primarily about configuring the macro correctly and implementing two hooks (`on_before_cmd`, `on_after_cmd`) plus a Session skill.

## Goals / Non-Goals

**Goals:**
- Define `Goodwizard.Agent` using `ReActAgent` macro with all Phase 2 tools registered
- Dynamic system prompt via `on_before_cmd` calling `ContextBuilder.build_system_prompt/2`
- In-memory conversation history via `Goodwizard.Skills.Session` Jido Skill
- Session updates via `on_after_cmd` hook
- Agent startable via `Goodwizard.Jido.start_agent/2` (OTP supervised)

**Non-Goals:**
- Persistent session storage (Phase 6)
- Multi-channel routing (Phase 5)
- Custom tool loop or strategy — use ReActAgent's built-in ReAct strategy
- Memory/summarization beyond raw message history

## Decisions

### 1. ReActAgent macro over manual strategy composition

**Choice:** `use Jido.AI.ReActAgent` with declarative config.

**Why:** The macro generates ask/await/ask_sync, request tracking, and Task.Supervisor setup. Manual composition would duplicate this work and create drift as jido_ai evolves. The macro's lifecycle hooks (`on_before_cmd`, `on_after_cmd`) provide the extension points we need.

**Alternative considered:** Composing `Jido.AI.Strategies.ReAct` manually with a GenServer — rejected because it reimplements what the macro provides.

### 2. Session as a Jido Skill (not GenServer)

**Choice:** `Goodwizard.Skills.Session` using `use Jido.Skill` with state_key `:session`.

**Why:** Jido Skills integrate with the agent's state map naturally. The session state lives inside the agent process — no extra process, no message passing overhead. The Skill's `mount/2` initializes session state when the agent starts.

**Alternative considered:** Separate GenServer per conversation — rejected because it adds process management complexity for state that's inherently per-agent-instance.

### 3. System prompt built per-turn in on_before_cmd

**Choice:** Call `ContextBuilder.build_system_prompt/2` in `on_before_cmd/2` before every ReAct cycle.

**Why:** Bootstrap files (AGENTS.md, SOUL.md, etc.) may change between turns. Reading small markdown files is cheap. This ensures the agent always reflects current workspace state without caching complexity.

**Alternative considered:** Build once at agent start, cache until workspace change — rejected as premature optimization that adds invalidation complexity.

### 4. Model configured at module level, overridable at start

**Choice:** Default `model: "anthropic:claude-sonnet-4-5"` in the macro config. Allow override via `initial_state` at start time.

**Why:** Sensible default with escape hatch. Config-level model override handled by reading `Goodwizard.Config` in `on_before_cmd` if needed.

## Risks / Trade-offs

**[jido_ai pre-1.0 API instability]** → Pin exact versions in mix.exs. Write integration tests against actual macro behavior. Keep Phase 4 surface area small — only use documented macro features.

**[on_before_cmd called every turn adds latency]** → Bootstrap file reads are <1ms for small files. Acceptable for an interactive assistant with multi-second LLM calls.

**[Session state lost on agent process crash]** → Acceptable for Phase 4. OTP supervision restarts the agent with fresh state. Persistence comes in Phase 6.

**[max_iterations: 20 may be too high for runaway loops]** → Start with 20, tune based on real usage. Each iteration involves an LLM call so cost/time is the natural brake.
