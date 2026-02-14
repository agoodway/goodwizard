# Phase 8: Telegram Channel — Tasks

## Backend

- [x] 1.1 Create Goodwizard.TelegramHandler using `JidoMessaging.Channels.Telegram.Handler` macro
- [x] 1.2 Implement `handle_message/2` callback — get/create AgentServer, call `ask_sync/3`, return `{:reply, text}` / `:noreply` / `{:error, reason}`
- [x] 1.3 Implement allow-list filtering in `handle_message/2` — check `allow_from` config, empty list allows all
- [x] 1.4 Add message splitting helper for responses exceeding 4096 characters — split at newline boundaries
- [x] 1.5 Wire TelegramHandler startup in Application when `channels.telegram.enabled` is true — add as static child
- [x] 1.6 Pass `character_overrides: %{voice: %{tone: :conversational, style: "brief and mobile-friendly"}}` in agent initial_state for Telegram agents

## Test

- [x] 2.1 Test TelegramHandler processes updates and routes to agent (with mocked Telegex)
- [x] 2.2 Test allow-list filtering (allowed user passes, blocked user gets :noreply, empty list allows all)
- [x] 2.3 Test message splitting for long responses (split at newlines, force split when no newlines)
- [x] 2.4 Test Telegram agent voice — character_overrides applied by Hydrator produce conversational tone in rendered prompt
