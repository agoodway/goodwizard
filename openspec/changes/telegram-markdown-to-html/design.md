## Context

Goodwizard's LLM produces standard markdown but all three Telegram delivery paths send raw text without `parse_mode`:

1. **Handler reply path** (`handler.ex`): Returns `{:reply, text}` 2-tuple. The jido_messaging Handler macro supports a 3-tuple `{:reply, text, opts}` that passes opts through `Deliver.deliver_outgoing` → `Telegram.send_message` → `build_telegram_opts` which extracts `:parse_mode`.
2. **Handler extra chunks** (`handler.ex`): Calls `Telegex.send_message(chat_id, chunk)` directly with no opts for split messages.
3. **Delivery module** (`delivery.ex`): `deliver_to_channel/4` calls `JidoMessaging.Deliver.send_to_room/4` without opts. The `/5` arity accepts keyword opts that flow to `channel.send_message`.

The upstream jido_messaging library already supports `parse_mode` throughout the chain — we just need to convert content and pass the option.

## Goals / Non-Goals

**Goals:**
- Format all Telegram messages with proper HTML rendering (bold, italic, code, links, etc.)
- Cover all three delivery paths consistently
- Preserve original markdown in the messaging DB for other channels
- Handle LLM output edge cases (nested formatting, code blocks with markdown inside, `snake_case` words)

**Non-Goals:**
- Modifying jido_messaging (upstream dependency)
- Adding markdown parsing dependencies (Earmark, etc.)
- Supporting Telegram's MarkdownV2 parse mode (HTML is more predictable)
- Converting markdown for non-Telegram channels (each channel can have its own formatter later)
- Making message splitting HTML-tag-aware (simple approach: most messages fit in one chunk; edge cases with split `<pre>` blocks are acceptable for now)

## Decisions

### 1. HTML parse mode over MarkdownV2

**Decision:** Use `parse_mode: "HTML"` with a markdown-to-HTML converter.

**Alternatives considered:**
- **MarkdownV2**: Telegram's MarkdownV2 requires escaping 18 special characters (`.`, `-`, `(`, `)`, `!`, `+`, etc.) in all non-formatted text. The LLM output is full of these characters, making reliable escaping fragile and error-prone.
- **Markdown (legacy)**: Telegram's legacy Markdown mode uses `*bold*` (not `**bold**`) which conflicts with standard markdown conventions.

**Rationale:** HTML is the most predictable — we control exactly what tags are produced, and Telegram's HTML subset is well-defined. Entity escaping (`&lt;`, `&gt;`, `&amp;`) is straightforward.

### 2. No new dependencies — regex-based converter

**Decision:** Write a focused regex-based converter in pure Elixir.

**Alternatives considered:**
- **Earmark**: Full CommonMark parser, but produces standard HTML (`<p>`, `<h1>`, `<ul>`, etc.) that Telegram doesn't support. Would need a second pass to strip/convert unsupported tags — more complexity than writing a targeted converter.
- **Pandoc via System.cmd**: External dependency, slow, overkill.

**Rationale:** The LLM's markdown subset is small and predictable. A targeted converter handles `**bold**`, `*italic*`, backtick code, fenced blocks, links, strikethrough, and blockquotes. No need for full CommonMark parsing.

### 3. Skip underscore-based bold/italic

**Decision:** Only convert asterisk-based formatting (`*`, `**`, `***`). Do not convert `_italic_` or `__bold__`.

**Rationale:** LLM output frequently contains `snake_case` identifiers, file paths like `config_file.ex`, and other underscore-heavy text outside code blocks. Word-boundary regexes help but don't eliminate false positives. The LLM primarily uses asterisks for emphasis, so underscores can be safely ignored.

### 4. Convert at the application boundary, not in the Formatter's caller

**Decision:** Apply conversion in Goodwizard's handler and Delivery module — the last stop before content leaves for Telegram.

- **Handler**: Convert in `dispatch_to_agent/4` after receiving the agent response but before `send_reply`. Save original markdown to DB, send HTML to Telegram.
- **Delivery**: Convert in `deliver_to_channel/4` with a `format_for_channel/2` helper that returns `{formatted_content, opts}` based on channel type.

**Rationale:** This keeps the formatter's integration surface small (two call sites) and ensures original markdown is preserved in the messaging DB for potential use by other channels.

### 5. Graceful fallback on conversion failure

**Decision:** If HTML conversion produces content that might be invalid, fall back to sending raw text without `parse_mode`.

**Rationale:** Telegram rejects messages with malformed HTML via `400 Bad Request`, which would cause message delivery failure. Sending unformatted text is better than failing to send at all.

## Risks / Trade-offs

- **[Regex edge cases]** Complex nested markdown or unusual LLM output could produce malformed HTML. → Mitigation: The converter processes code blocks first (protecting their content), applies patterns in strict priority order, and includes a fallback to raw text.
- **[Split messages with HTML tags]** If a message is split at a newline inside a `<pre>` block, the chunk will have unbalanced tags. → Mitigation: Accept this for now. Most messages fit in one 4096-char chunk. A tag-balancing pass can be added later if this becomes a real issue.
- **[Telegram API changes]** Telegram could change supported HTML tags. → Mitigation: Low risk — the supported tag set has been stable for years. The converter only uses well-established tags.
