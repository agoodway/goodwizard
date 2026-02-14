## REWRITTEN — TelegramHandler replaces Poller

The `Goodwizard.Channels.Telegram.Poller` module has been **replaced** by `Goodwizard.TelegramHandler`, which uses the `JidoMessaging.Channels.Telegram.Handler` macro to generate a Telegex-based polling handler.

## ADDED Requirements

### Requirement: TelegramHandler connects on boot
`Goodwizard.TelegramHandler` SHALL use `JidoMessaging.Channels.Telegram.Handler` macro. On boot, the handler SHALL call Telegex `get_me` to verify bot identity and `delete_webhook` to ensure clean polling state.

#### Scenario: Successful boot with valid token
- **WHEN** the TelegramHandler starts and `Application.get_env(:telegex, :token)` returns a valid token
- **THEN** the handler SHALL verify bot identity via `get_me`, delete any existing webhook, and begin polling for updates

#### Scenario: Missing token prevents start
- **WHEN** the TelegramHandler starts and `Application.get_env(:telegex, :token)` returns `nil`
- **THEN** the handler SHALL fail to start with an error indicating the token is missing

### Requirement: TelegramHandler processes updates via Ingest pipeline
The handler SHALL process incoming Telegram updates through jido_messaging's Ingest pipeline, which auto-resolves rooms and participants from the update data.

#### Scenario: Update creates room for new chat
- **WHEN** a Telegram update arrives from a chat_id with no existing room
- **THEN** the Ingest pipeline SHALL create a room with external binding `{:telegram, bot_name, chat_id}` and resolve the participant

#### Scenario: Update reuses existing room
- **WHEN** a Telegram update arrives from a chat_id with an existing room
- **THEN** the Ingest pipeline SHALL return the existing room without creating a new one

### Requirement: TelegramHandler routes messages to agent
The `handle_message/2` callback SHALL get or create an AgentServer for the chat and call `Goodwizard.Agent.ask_sync/3` with the message text.

#### Scenario: Agent response returned as reply
- **WHEN** `ask_sync/3` returns `{:ok, answer}`
- **THEN** the callback SHALL return `{:reply, answer}` for the handler to deliver via Telegex

#### Scenario: Agent error returns error message
- **WHEN** `ask_sync/3` returns `{:error, reason}`
- **THEN** the callback SHALL log the error and return `{:reply, "Sorry, I encountered an error. Please try again."}`

### Requirement: Filter messages by allow_from list
The `handle_message/2` callback SHALL check the sender's Telegram user ID against the configured `allow_from` list before processing.

#### Scenario: Allowed user's message is processed
- **WHEN** a message arrives from a user whose ID is in the `allow_from` list
- **THEN** the message SHALL be routed to an AgentServer for processing

#### Scenario: Blocked user's message is ignored
- **WHEN** a message arrives from a user whose ID is NOT in the `allow_from` list and the list is non-empty
- **THEN** the callback SHALL return `:noreply` (silent discard)

#### Scenario: Empty allow_from list allows all users
- **WHEN** the `allow_from` list is empty
- **THEN** all messages SHALL be processed regardless of sender

### Requirement: Auto-start when enabled in config
The TelegramHandler SHALL be added as a static application child when `channels.telegram.enabled` is `true` in config.

#### Scenario: Telegram enabled starts handler
- **WHEN** the application starts and `Config.get([:channels, :telegram, :enabled])` returns `true`
- **THEN** `Goodwizard.TelegramHandler` SHALL be included in the application supervision tree as a static child

#### Scenario: Telegram disabled skips handler
- **WHEN** the application starts and `Config.get([:channels, :telegram, :enabled])` returns `false` or is absent
- **THEN** `Goodwizard.TelegramHandler` SHALL NOT be started
