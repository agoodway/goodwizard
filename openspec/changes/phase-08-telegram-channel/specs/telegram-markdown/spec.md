## REMOVED — Superseded by Telegex parse_mode

The `Goodwizard.Channels.Telegram.Markdown` module has been **removed**. Markdown-to-HTML conversion is no longer needed as a custom module.

### What replaces it

Telegex handles message formatting natively via the `parse_mode` option when sending messages:
- `parse_mode: "MarkdownV2"` — Telegex parses Markdown formatting
- `parse_mode: "HTML"` — Telegex parses HTML formatting

The `JidoMessaging.Channels.Telegram.Handler` macro's delivery pipeline passes `parse_mode` through to Telegex automatically.

### Migration notes

- All references to `Telegram.Markdown.to_html/1` should be removed
- No custom formatting conversion is needed
- If specific pre-processing is required in the future, it can be a simple function in the TelegramHandler rather than a separate module
