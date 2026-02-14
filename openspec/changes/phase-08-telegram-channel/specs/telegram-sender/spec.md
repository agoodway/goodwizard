## REWRITTEN — Sending handled by jido_messaging via Telegex

The `Goodwizard.Channels.Telegram.Sender` module has been **replaced**. Message sending is now handled by `JidoMessaging.Channels.Telegram.send_message/3` via Telegex. Markdown conversion is handled by Telegex's `parse_mode` option.

The only remaining custom requirement is message splitting for long responses.

## ADDED Requirements

### Requirement: Split long messages before sending
The TelegramHandler SHALL split responses exceeding Telegram's 4096 character limit into multiple messages, splitting at newline boundaries.

#### Scenario: Short message sent directly
- **WHEN** the response text is 4096 characters or fewer
- **THEN** a single message SHALL be sent via the handler's delivery pipeline

#### Scenario: Long message split and sent in parts
- **WHEN** the response text exceeds 4096 characters
- **THEN** the message SHALL be split into chunks of 4096 characters or fewer, splitting at newline boundaries, and each chunk SHALL be sent as a separate message in order

#### Scenario: Split on newline before limit
- **WHEN** a message exceeds 4096 characters and contains newlines
- **THEN** the split SHALL occur at the last newline before the 4096 character boundary

#### Scenario: Force split when no newline available
- **WHEN** a message exceeds 4096 characters with no newline in the first 4096 characters
- **THEN** the split SHALL occur at exactly 4096 characters
