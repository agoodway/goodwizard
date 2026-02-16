## Why

The LLM produces standard markdown (`**bold**`, `` `code` ``, `[links](url)`, etc.) but Telegram receives it as raw text — users see literal `**` markers instead of formatted text. No `parse_mode` is set on any of the three message delivery paths, and no markdown-to-HTML conversion exists anywhere in the codebase.

## What Changes

- Add a markdown-to-Telegram-HTML formatter module that converts standard LLM markdown to the subset of HTML that Telegram's Bot API supports (`<b>`, `<i>`, `<code>`, `<pre>`, `<a>`, `<s>`, `<blockquote>`)
- Update the Telegram handler's reply path to convert responses to HTML and pass `parse_mode: "HTML"` via the jido_messaging 3-tuple reply form `{:reply, text, opts}`
- Update the Telegram handler's extra-chunk path (direct `Telegex.send_message` calls for split messages) to also pass `parse_mode: "HTML"`
- Update the Delivery module to convert content and pass `parse_mode: "HTML"` when delivering to Telegram channels, covering both the Send action and CronRunner paths

## Capabilities

### New Capabilities

- `telegram-html-formatter`: Markdown-to-Telegram-HTML conversion module. Covers the conversion algorithm (code block extraction, HTML entity escaping, markdown syntax replacement), the supported formatting subset, and edge case handling.
- `telegram-message-formatting`: Integration of the formatter into all three Telegram delivery paths (handler reply, handler extra chunks, Delivery module) with `parse_mode: "HTML"` propagation.

### Modified Capabilities

None. No existing specs are affected.

## Impact

- **Code**: `lib/goodwizard/channels/telegram/handler.ex` (reply/chunk paths), `lib/goodwizard/messaging/delivery.ex` (channel delivery), plus one new module
- **APIs**: No public API changes. The jido_messaging `{:reply, text, opts}` 3-tuple and `JidoMessaging.Deliver.send_to_room/5` optional opts are already supported upstream — we just start using them
- **Dependencies**: No new deps. The formatter is pure Elixir regex-based conversion
- **Systems**: Telegram message rendering changes from plain text to HTML-formatted. Original markdown is preserved in the messaging DB; only the Telegram-bound content is converted
