# Phase 8: Telegram Channel

## Why

Telegram is the primary mobile interface for Goodwizard, enabling interaction from anywhere. The long-polling approach is simple and reliable, requiring no webhook infrastructure. Each Telegram chat gets its own agent instance with independent memory and session state.

## What

### Goodwizard.Channels.Telegram.Poller (GenServer)

Port of `nanobot/channels/telegram.py` (408 lines). Long-polling GenServer that calls Telegram Bot API `getUpdates`.

- On init: read config (token, allow_from list), schedule first poll
- Poll loop: call getUpdates via Req, process each message
- Per-message: check allow_from list, get-or-create AgentServer via Jido instance (`"telegram:#{chat_id}"`), use `ask_sync/3`, send response
- Schedule next poll after 100ms

### Goodwizard.Channels.Telegram.Sender

Outbound message formatting + API calls:
- Convert markdown to Telegram HTML
- Split long messages (4096 char limit)
- POST to `https://api.telegram.org/bot{token}/sendMessage`

### Goodwizard.Channels.Telegram.Markdown

Port of `_markdown_to_telegram_html` (telegram.py lines 23-50+):
- Code blocks → `<pre>` tags
- Inline code → `<code>` tags
- Bold `**text**` → `<b>text</b>`
- Italic `*text*` → `<i>text</i>`
- Headers → plain text
- Blockquotes → plain text
- HTML-escape remaining `<>&` chars

### Application Integration

Start Telegram poller if configured:
```elixir
if Goodwizard.Config.get(:channels, :telegram, :enabled) do
  Goodwizard.ChannelSupervisor.start_channel(Goodwizard.Channels.Telegram.Poller, [])
end
```

## Dependencies

- Phase 5 (CLI Channel) — uses same ChannelSupervisor + AgentServer + ask/await pattern

## Reference

- `nanobot/channels/telegram.py` (408 lines)
