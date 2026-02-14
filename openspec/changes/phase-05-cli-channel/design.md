## Context

Goodwizard is a personal AI coding assistant built on jido v2 and jido_ai. Phases 1–4 establish the foundation: project scaffold with Config GenServer, five Jido Actions, ReAct integration via ContextBuilder and ToolAdapter, and the Agent module using `ReActAgent` macro with session tracking. Phase 5 connects all prior work into a working CLI REPL — the first time Goodwizard is usable end-to-end.

The CLI channel is the primary development and testing interface. It reads user input from stdin, dispatches to the agent via `ask_sync/3`, and prints responses. Two mix tasks (`goodwizard.setup` and `goodwizard.cli`) provide the entry points.

`Goodwizard.Messaging` (from Phase 1, backed by jido_messaging) replaces the need for a custom ChannelSupervisor. The CLI Server creates a Messaging room on init and uses it for conversation tracking and message persistence.

## Goals / Non-Goals

**Goals:**
- CLI GenServer that runs a REPL loop dispatching to the agent
- CLI Server creates a Messaging room for conversation persistence
- Mix task for workspace setup (dirs + default config)
- Mix task for launching the CLI channel
- End-to-end agent interaction via the CLI

**Non-Goals:**
- Custom ChannelSupervisor (replaced by `Goodwizard.Messaging` from Phase 1)
- Multi-channel routing or channel abstraction layer (future phases)
- Persistent session storage (Phase 6)
- Custom prompt rendering or theming
- Input history or readline-style editing (rely on terminal defaults)
- Graceful shutdown signaling beyond normal OTP supervision

## Decisions

### 1. jido_messaging replaces ChannelSupervisor

**Choice:** Use `Goodwizard.Messaging` (backed by jido_messaging) for room/channel supervision instead of a custom `ChannelSupervisor` DynamicSupervisor.

**Why:** jido_messaging provides room supervision, signal bus, deduplication, and channel management out of the box. A custom DynamicSupervisor would duplicate functionality that jido_messaging already handles. The CLI Server doesn't need the Channel behaviour (since `IO.gets/1` is blocking and not a platform transport), but it uses Messaging rooms for conversation tracking.

**Alternative considered:** Custom `ChannelSupervisor` DynamicSupervisor with `start_channel/2` — rejected because jido_messaging provides all supervision needs and the CLI is the only channel that doesn't fit the Channel behaviour pattern.

### 2. REPL loop in a linked Task (not GenServer callbacks)

**Choice:** Spawn a linked `Task` from the CLI Server's `init/1` that runs the blocking `IO.gets/1` loop.

**Why:** `IO.gets/1` is blocking and cannot run inside GenServer callbacks without stalling the process. A linked Task crashes the GenServer if the loop dies (and vice versa), keeping lifecycle management simple. The GenServer itself holds state (agent pid, room_id, config) and the Task handles the blocking I/O.

**Alternative considered:** Using `handle_continue` with recursive self-sends — rejected because `IO.gets` blocks the process mailbox, preventing GenServer from processing other messages.

### 3. Agent started by CLI Server via handler function pattern

**Choice:** The CLI Server starts the AgentServer in its `init/1` via `Goodwizard.Jido.start_agent/2` with id `"cli:direct"`. This mirrors the pattern that the Telegram handler (Phase 8) will use.

**Why:** The agent lifecycle is tied to the channel that owns it. If the CLI Server restarts, it gets a fresh agent. This avoids orphaned agent processes and keeps the ownership model clear: channel owns agent. The handler function pattern (`start_agent` → `ask_sync` → return response) is consistent across CLI and Telegram.

**Alternative considered:** Pre-starting the agent in the supervision tree — rejected because it couples agent lifecycle to application start rather than channel start.

### 4. Workspace setup as a separate mix task

**Choice:** `mix goodwizard.setup` creates workspace directories and default config, separate from `mix goodwizard.cli`.

**Why:** Setup is a one-time operation, while CLI launch is repeated. Separating them lets users re-run setup without starting the CLI, and lets the CLI task assume workspace exists. The CLI task can check for workspace and suggest running setup if missing.

**Alternative considered:** Auto-setup in CLI task if workspace missing — rejected because implicit side effects in a launch command are surprising.

### 5. CLI uses Messaging rooms for persistence

**Choice:** The CLI Server creates a room via `Goodwizard.Messaging.get_or_create_room_by_external_binding(:cli, "goodwizard", "direct")` on init, and saves all user + assistant messages to the room.

**Why:** This gives the CLI the same conversation tracking that Telegram gets for free via jido_messaging's Ingest pipeline. Even though the CLI doesn't implement the Channel behaviour, using Messaging rooms means conversation history is available for Phase 6 persistence and Phase 10 status reporting.

**Alternative considered:** No message persistence in CLI — rejected because it would make the CLI a second-class channel with no history.

## Risks / Trade-offs

**[IO.gets blocks the Task, no concurrent input handling]** → Acceptable for a single-user CLI. The REPL is inherently sequential: prompt → input → response → prompt.

**[Agent crash kills CLI Server via linked Task]** → By design. OTP supervision restarts the CLI Server, which starts a fresh agent. Conversation state is preserved in the Messaging room.

**[120s ask_sync timeout may be too short for complex tool chains]** → Start with 120s based on typical ReAct cycles. Can be made configurable via Config if needed.

**[mix goodwizard.cli must keep the application alive]** → Use `Process.sleep(:infinity)` or monitor the CLI Server process to keep the mix task running. If the CLI Server terminates, the mix task should exit.
