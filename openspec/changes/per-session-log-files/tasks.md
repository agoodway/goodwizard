## 1. Configuration

- [x] 1.1 Add `session.max_cli_sessions` to `@defaults` in `lib/goodwizard/config.ex` (default: 50)
- [x] 1.2 Add `session.max_cli_sessions` to `config.toml` (commented out with description)
- [x] 1.3 Add `session.max_cli_sessions` to `@default_config` in `lib/mix/tasks/goodwizard.setup.ex`

## 2. Session Keying — Channels

- [x] 2.1 Set `session_key` to `"cli-direct-{unix_ts}"` in CLI server's `start_cli_agent/1` initial state
- [x] 2.2 Set `session_key` to `"telegram-{chat_id}"` in Telegram handler's `get_or_create_agent/1` initial state

## 3. Session Loading on Mount

- [x] 3.1 Update `Session.mount/2` to accept agent config/state and attempt `load_session/2` when `session_key` is present
- [x] 3.2 If session file exists, populate `messages`, `created_at`, and `metadata` from the loaded data

## 4. Session Cleanup

- [x] 4.1 Add `cleanup_old_sessions/0` function to `Goodwizard.Plugins.Session` that lists `cli-direct-*.jsonl`, sorts by mtime, deletes excess files
- [x] 4.2 Call `cleanup_old_sessions/0` from CLI server `init/1` after agent starts

## 5. Tests

- [x] 5.1 Test CLI server sets timestamped `session_key` in agent initial state
- [x] 5.2 Test Telegram handler sets `telegram-{chat_id}` session key in agent initial state
- [x] 5.3 Test `Session.mount/2` loads existing session file when `session_key` matches
- [x] 5.4 Test `Session.mount/2` starts empty when no file matches
- [x] 5.5 Test cleanup deletes oldest CLI session files beyond retention limit
- [x] 5.6 Test cleanup ignores non-CLI session files (e.g., `telegram-*.jsonl`)
- [x] 5.7 Test cleanup handles deletion errors gracefully (logs warning, doesn't crash)
