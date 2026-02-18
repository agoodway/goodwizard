## ADDED Requirements

### Requirement: Handler reply path sends HTML with parse_mode
The Telegram handler SHALL convert agent responses to Telegram HTML before sending and SHALL return the 3-tuple `{:reply, html, parse_mode: "HTML"}` form to the jido_messaging Handler macro.

#### Scenario: Agent response with markdown formatting
- **WHEN** the agent returns a response containing markdown formatting
- **THEN** the handler converts it to Telegram HTML and returns `{:reply, html_content, parse_mode: "HTML"}`

#### Scenario: Original markdown preserved in messaging DB
- **WHEN** the agent returns a response
- **THEN** the handler saves the original markdown to the messaging DB before converting to HTML for Telegram delivery

### Requirement: Handler extra chunks send HTML with parse_mode
When a response is split across multiple Telegram messages, the handler SHALL pass `parse_mode: "HTML"` to all `Telegex.send_message` calls for extra chunks.

#### Scenario: Multi-chunk message delivery
- **WHEN** an agent response exceeds 4096 characters and is split into chunks
- **THEN** each chunk sent via `Telegex.send_message` includes `parse_mode: "HTML"`

### Requirement: Delivery module formats for Telegram channel
The Delivery module SHALL convert content to Telegram HTML and pass `parse_mode: "HTML"` when delivering to Telegram-bound rooms. Non-Telegram channels SHALL receive unmodified content.

#### Scenario: Delivery to Telegram binding
- **WHEN** `deliver_to_bindings` delivers to a room with a Telegram binding
- **THEN** the content is converted to Telegram HTML and `parse_mode: "HTML"` is passed to `JidoMessaging.Deliver.send_to_room/5`

#### Scenario: Delivery to non-Telegram channel
- **WHEN** a future channel binding exists that is not Telegram
- **THEN** the content is passed through unmodified with no `parse_mode` option

#### Scenario: ScheduledTaskRunner delivery uses HTML formatting
- **WHEN** a scheduled task completes and delivers results via `Delivery.deliver_to_bindings`
- **THEN** the response content is converted to Telegram HTML before delivery

### Requirement: Fallback on conversion failure
If HTML conversion produces content that Telegram rejects, the system SHALL fall back to sending raw text without `parse_mode`.

#### Scenario: Telegram rejects malformed HTML
- **WHEN** a converted message causes a Telegram API error
- **THEN** the system retries sending the original unconverted text without `parse_mode`
