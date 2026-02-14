## Context

Goodwizard's channel architecture uses `Goodwizard.Messaging` (backed by jido_messaging) for room/channel supervision, message persistence, and signal routing. The CLI channel (Phase 5) established the pattern: create a Messaging room, start an AgentServer, dispatch via `ask_sync/3`, save messages.

The Telegram channel ports `nanobot/channels/telegram.py` (408 lines) to Elixir. Instead of a custom Poller/Sender/Markdown implementation, we use jido_messaging's `JidoMessaging.Channels.Telegram.Handler` macro, which generates a Telegex-based polling handler with ingest/deliver pipelines. The only custom code is the `handle_message/2` callback.

## Goals / Non-Goals

**Goals:**
- TelegramHandler using `JidoMessaging.Channels.Telegram.Handler` macro for polling and message processing
- `handle_message/2` callback that routes to per-chat AgentServer instances
- Allow-list filtering so only authorized Telegram users can interact
- Message splitting for responses exceeding Telegram's 4096 character limit
- Config-driven startup — only runs when `channels.telegram.enabled` is true
- Rooms auto-resolved by jido_messaging's Ingest pipeline

**Non-Goals:**
- Custom Poller GenServer (replaced by Handler macro)
- Custom Sender module (replaced by Telegex delivery)
- Custom Markdown conversion module (replaced by Telegex parse_mode)
- Webhook mode — long-polling is simpler and requires no public endpoint
- Media/file handling — text messages only for now
- Inline queries, callbacks, or bot commands beyond plain text
- Rate limiting or queuing — Telegram's own rate limits are sufficient at current scale

## Decisions

### 1. jido_messaging Handler macro replaces custom Poller

**Decision**: Use `JidoMessaging.Channels.Telegram.Handler` macro instead of a custom polling GenServer.

**Rationale**: The Handler macro generates a complete Telegex polling handler including boot sequence (`get_me`, `delete_webhook`), update processing, and the ingest/deliver pipeline. This eliminates ~200 lines of custom polling code. The only custom code needed is the `handle_message/2` callback which contains the business logic.

**Alternatives considered**: Custom GenServer polling via Req — rejected because jido_messaging provides this functionality with proper error handling, offset tracking, and Telegex integration.

### 2. Telegex replaces Req for Telegram API

**Decision**: All Telegram API calls go through Telegex (via jido_messaging) instead of direct Req HTTP calls.

**Rationale**: Telegex is a mature Telegram bot library that handles API encoding/decoding, error handling, and the polling lifecycle. It's already a dependency of jido_messaging. Using Req directly would duplicate functionality and miss Telegex's built-in retry logic and type safety.

**Alternatives considered**: Direct Req HTTP calls to Telegram Bot API — rejected because Telegex provides all this with proper typing and error handling.

### 3. Rooms replace per-chat AgentServer tracking (Ingest auto-resolves)

**Decision**: The Handler macro's Ingest pipeline auto-resolves rooms and participants from Telegram updates. The handler doesn't need to manually track `chat_id → AgentServer` mappings.

**Rationale**: jido_messaging's Ingest pipeline calls `get_or_create_room_by_external_binding` automatically when processing Telegram updates. This creates rooms with the correct Telegram binding (`{:telegram, bot_name, chat_id}`) and resolves participants. The handler callback receives the resolved room context.

**Alternatives considered**: Manual chat_id → AgentServer tracking in handler state — rejected because the Ingest pipeline handles this automatically.

### 4. Markdown conversion deferred to Telegex parse_mode

**Decision**: Instead of a custom `Markdown.to_html/1` module, use Telegex's `parse_mode: "MarkdownV2"` or `parse_mode: "HTML"` option when sending messages.

**Rationale**: Telegex handles message formatting natively. A custom conversion module added complexity (regex-based HTML conversion, tag ordering, escaping) that Telegex's parse_mode handles correctly. If specific formatting needs arise, they can be addressed by a simple pre-processing function rather than a full conversion module.

**Alternatives considered**: Custom `Telegram.Markdown.to_html/1` module — rejected because Telegex's parse_mode is simpler and handles edge cases better.

### 5. Allow-list via handler callback

**Decision**: The allow-list check happens inside the `handle_message/2` callback. Blocked users receive `:noreply` (silent discard).

**Rationale**: The allow-list is simple enough to be a conditional in the callback. A separate Gating behaviour would add abstraction overhead for what amounts to an `if` check against a config list. The callback reads `allow_from` from `Goodwizard.Config`.

**Alternatives considered**: JidoMessaging Gating behaviour — considered for extensibility but rejected as over-engineering for a simple user ID list check.

## Risks / Trade-offs

**[Handler macro hides polling internals]** → The macro generates the Telegex handler module. Debugging polling issues requires understanding Telegex internals. Mitigation: Telegex is well-documented and the macro's generated code is inspectable.

**[Long response times block update processing]** → `ask_sync/3` with 120s timeout means other updates wait while the agent processes. Acceptable for single-user or low-volume use. For higher concurrency, the handler could dispatch to a Task pool.

**[Message splitting may break formatting]** → Splitting at 4096 chars could cut mid-formatting. The splitting helper splits on newline boundaries before the limit to minimize this risk.

**[No persistent offset storage]** → Telegex manages the poll offset in memory. On application restart, Telegram may re-deliver recent messages. Acceptable — messages older than 24 hours are dropped by Telegram.
