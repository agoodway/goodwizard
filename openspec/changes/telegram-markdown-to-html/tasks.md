## 1. Formatter Module

- [ ] 1.1 Create `Goodwizard.Channels.Telegram.Formatter` at `lib/goodwizard/channels/telegram/formatter.ex` with `to_telegram_html/1` public function
- [ ] 1.2 Implement code block extraction — extract fenced code blocks (``` ```lang...``` ```) and inline code (`` ` ``) into placeholders before processing
- [ ] 1.3 Implement HTML entity escaping — escape `&`, `<`, `>` in non-code text
- [ ] 1.4 Implement markdown-to-HTML conversions: `***` → `<b><i>`, `**` → `<b>`, `*` → `<i>`, `~~` → `<s>`, `[text](url)` → `<a>`, `> ` lines → `<blockquote>`
- [ ] 1.5 Implement code placeholder restoration — restore fenced blocks as `<pre>` / `<pre><code class="language-X">` and inline code as `<code>`, with HTML-escaped content

## 2. Formatter Tests

- [ ] 2.1 Create `test/goodwizard/channels/telegram/formatter_test.exs` with tests for bold, italic, bold-italic, strikethrough, inline code, fenced code blocks, links, blockquotes
- [ ] 2.2 Add edge case tests: HTML entity escaping, plain text passthrough, empty string, unmatched markers, snake_case preservation, markdown inside code blocks, nested formatting

## 3. Handler Integration

- [ ] 3.1 Update `dispatch_to_agent/4` in `handler.ex` to convert agent response via `Formatter.to_telegram_html/1` before calling `send_reply`, preserving original markdown for DB save
- [ ] 3.2 Update `send_reply/2` in `handler.ex` to return `{:reply, text, parse_mode: "HTML"}` 3-tuple instead of `{:reply, text}` 2-tuple
- [ ] 3.3 Update `send_extra_chunks/2` in `handler.ex` to pass `parse_mode: "HTML"` to `Telegex.send_message/3`

## 4. Delivery Integration

- [ ] 4.1 Add `format_for_channel/2` private function to `delivery.ex` that converts content to Telegram HTML for `:telegram` channel and returns `{formatted_content, [parse_mode: "HTML"]}`, passthrough for other channels
- [ ] 4.2 Update `deliver_to_channel/4` in `delivery.ex` to call `format_for_channel/2` and pass opts to `JidoMessaging.Deliver.send_to_room/5`

## 5. Handler Test Updates

- [ ] 5.1 Update existing handler tests in `handler_test.exs` that assert `{:reply, _}` 2-tuple to accept `{:reply, _, _}` 3-tuple with `parse_mode: "HTML"`
