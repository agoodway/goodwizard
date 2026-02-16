## Why

Every agent currently saves its session to the same `default.jsonl` file (or whatever `session_key` is in state, which is always `"default"` since nothing sets it). This means CLI sessions overwrite each other, Telegram chat sessions all share one file, and there's no way to review or restore a previous conversation. Each agent instance should persist to its own session file keyed by its identity (channel + chat ID).

## What Changes

- Derive a unique `session_key` from the agent's `channel` and `chat_id` at agent startup instead of falling back to `"default"`
- CLI agents use a timestamped key (e.g., `cli-direct-1718000000`) so each CLI run gets its own file
- Telegram agents use a stable key (e.g., `telegram-12345`) so the same chat resumes across restarts
- Load previous session history on agent start when a matching session file exists (Telegram only — CLI starts fresh)
- Add a config option to control max session files retained, with cleanup of old CLI sessions

## Capabilities

### New Capabilities

- `session-keying`: Derive unique session keys per agent instance from channel + chat ID, with channel-specific policies (timestamped vs stable)
- `session-cleanup`: Automatic cleanup of old session files beyond a configurable retention limit

### Modified Capabilities

_None — no existing specs to modify._

## Impact

- `lib/goodwizard/agent.ex` — session key derivation logic in agent lifecycle hooks
- `lib/goodwizard/channels/cli/server.ex` — pass timestamped session info to agent initial state
- `lib/goodwizard/channels/telegram/handler.ex` — pass stable chat-based session info to agent initial state
- `lib/goodwizard/plugins/session.ex` — session load on mount, list/cleanup helpers
- `lib/goodwizard/config.ex` — new `session.max_files` config option
- `lib/goodwizard/shutdown_handler.ex` — already uses `session_key` from state, no changes needed
- `priv/workspace/sessions/` — will contain multiple `.jsonl` files instead of one
