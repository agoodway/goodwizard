## ADDED Requirements

### Requirement: CLI agents use timestamped session keys

The CLI channel SHALL set `session_key` in the agent's initial state to `cli-direct-{unix_timestamp}` where `{unix_timestamp}` is the current Unix epoch in seconds at server start time.

#### Scenario: CLI server starts a new agent

- **WHEN** the CLI server starts and creates an agent
- **THEN** the agent's initial state `session_key` SHALL be `"cli-direct-{ts}"` where `{ts}` is the Unix timestamp at start time

#### Scenario: Two CLI sessions started at different times

- **WHEN** two CLI servers start 10 seconds apart
- **THEN** each agent SHALL have a different `session_key` and write to separate `.jsonl` files

### Requirement: Telegram agents use stable chat-based session keys

The Telegram channel SHALL set `session_key` in the agent's initial state to `telegram-{chat_id}` where `{chat_id}` is the Telegram chat identifier.

#### Scenario: Telegram handler creates agent for a chat

- **WHEN** a message arrives from Telegram chat `12345`
- **THEN** the agent's initial state `session_key` SHALL be `"telegram-12345"`

#### Scenario: Same chat across restarts

- **WHEN** the application restarts and a message arrives from the same Telegram chat
- **THEN** the agent SHALL use the same `session_key` as before the restart, and its session file SHALL contain the prior history

### Requirement: Session plugin loads existing history on mount

The `Session` plugin `mount/2` SHALL attempt to load an existing session file when the agent's initial state contains a `session_key`. If a matching file exists, the plugin SHALL populate `session.messages`, `session.created_at`, and `session.metadata` from the file.

#### Scenario: Agent starts with a session key that has a prior file

- **WHEN** an agent mounts with `session_key` `"telegram-12345"` and `sessions/telegram-12345.jsonl` exists
- **THEN** the session state SHALL contain the messages from the file

#### Scenario: Agent starts with a session key that has no prior file

- **WHEN** an agent mounts with `session_key` `"cli-direct-1718000000"` and no matching file exists
- **THEN** the session state SHALL be initialized empty (default behavior)

#### Scenario: Agent starts without a session key

- **WHEN** an agent mounts without `session_key` in its initial state
- **THEN** the session plugin SHALL NOT attempt to load any file and SHALL initialize empty

### Requirement: Agent persists session using the derived key

The agent's `persist_session/1` SHALL use the `session_key` from agent state. This is existing behavior — the key already reads from state with a `"default"` fallback. No change is needed to the persistence path itself.

#### Scenario: Agent completes a conversation turn

- **WHEN** a CLI agent with `session_key` `"cli-direct-1718000000"` completes a turn
- **THEN** the session SHALL be saved to `sessions/cli-direct-1718000000.jsonl`
