## Context

Currently every agent persists its session to `workspace/sessions/default.jsonl`. The `session_key` field in agent state is never explicitly set by any channel, so `persist_session/1` in `Goodwizard.Agent` always falls back to `"default"`. This means:

- Every CLI run overwrites the previous session
- Multiple Telegram chats would overwrite each other (only one agent typically runs, but the path exists)
- There's no session history or ability to review past conversations

The session plugin already supports arbitrary keys — the infrastructure is in place, nothing sets the key.

## Goals / Non-Goals

**Goals:**

- Each agent instance writes to its own session file
- CLI sessions use timestamped keys so history accumulates across runs
- Telegram sessions use stable keys so the same chat resumes its history
- Old CLI session files are cleaned up automatically to prevent unbounded growth
- Session history loads on agent start for channels that want continuity (Telegram)

**Non-Goals:**

- Session search or indexing (just file-per-session)
- Session export/import in other formats
- Cross-device session sync
- UI for browsing session history

## Decisions

### 1. Session key format

**Decision:** `{channel}-{chat_id}` with channel-specific suffixes.

- CLI: `cli-direct-{unix_timestamp}` — each run gets a unique file
- Telegram: `telegram-{chat_id}` — stable across restarts

**Rationale:** The channel and chat_id are already in agent initial state. Using them directly produces predictable, debuggable filenames. Timestamps for CLI avoid collisions without needing UUIDs.

**Alternative considered:** UUID-based keys — rejected because they're opaque and make manual inspection harder.

### 2. Where to set the session key

**Decision:** Each channel sets `session_key` in the agent's `initial_state` map when calling `Jido.start_agent`.

**Rationale:** Channels already pass `workspace`, `channel`, and `chat_id` in initial state. Adding `session_key` there keeps key derivation close to the channel-specific logic. The agent's `persist_session/1` already reads `session_key` from state with a `"default"` fallback, so no agent code changes are needed for persistence.

**Alternative considered:** Deriving the key inside the agent's `on_before_cmd` — rejected because it couples agent logic to channel naming conventions.

### 3. Session loading on start

**Decision:** The `Session` plugin's `mount/2` callback checks for an existing session file when the agent's state contains a `session_key`. If found, it pre-populates `session.messages`, `session.created_at`, and `session.metadata`.

**Rationale:** The plugin already manages session state and has `load_session/2`. Doing it at mount time means the first conversation turn already has history available.

CLI agents set a timestamped key that won't match any prior file, so they naturally start fresh. Telegram agents reuse the same key, so they naturally resume.

### 4. Session cleanup strategy

**Decision:** A periodic cleanup that runs on CLI server init. It lists session files matching `cli-direct-*.jsonl`, sorts by mtime, and deletes files beyond the configured retention count.

**Rationale:** CLI is the only channel that creates unbounded session files (one per run). Telegram keys are stable (one per chat). Running cleanup at CLI start keeps it simple — no background timer needed.

Config: `session.max_cli_sessions` (default: 50).

**Alternative considered:** A separate GenServer with periodic timer — rejected as over-engineered for this use case.

## Risks / Trade-offs

- **[Risk] Existing `default.jsonl` becomes orphaned** → Acceptable. It won't be written to anymore. Users can delete it manually. Not worth adding migration logic.
- **[Risk] Many Telegram chats = many session files** → Mitigated by the fact that Telegram chats are bounded by allow-list config. Could add Telegram cleanup later if needed.
- **[Risk] Cleanup deletes a session the user wanted** → Mitigated by defaulting to 50 retained sessions, which covers weeks of typical usage.
