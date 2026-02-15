## ADDED Requirements

### Requirement: Token estimation for messages
The system SHALL estimate token counts for text content using a character-ratio heuristic (characters ÷ 4, rounded up). The estimator SHALL accept a single string or a list of session message maps and return an integer token estimate.

#### Scenario: Estimate tokens for a plain string
- **WHEN** the estimator receives a 400-character string
- **THEN** it returns 100

#### Scenario: Estimate tokens for a list of messages
- **WHEN** the estimator receives a list of 3 messages with contents of 100, 200, and 300 characters
- **THEN** it returns the sum of individual estimates (25 + 50 + 75 = 150)

#### Scenario: Estimate tokens for an empty string
- **WHEN** the estimator receives an empty string
- **THEN** it returns 0

### Requirement: Configurable context budget
The system SHALL expose two new config keys under `[agent]` in config.toml: `context_budget` (integer, default 100000) and `max_message_tokens` (integer, default 30000). Both SHALL be validated within numeric ranges and fall back to defaults when out of range.

#### Scenario: Defaults applied when not configured
- **WHEN** config.toml has no `context_budget` or `max_message_tokens` keys
- **THEN** the system uses 100000 for context_budget and 30000 for max_message_tokens

#### Scenario: Custom values loaded from config
- **WHEN** config.toml sets `context_budget = 50000` and `max_message_tokens = 10000`
- **THEN** the system uses those values

#### Scenario: Out-of-range value falls back to default
- **WHEN** config.toml sets `context_budget = 0`
- **THEN** the system logs a warning and uses the default 100000

### Requirement: Per-message truncation on add
The system SHALL truncate the content of any message whose estimated token count exceeds `max_message_tokens` when it is added to the session. Truncated content SHALL be cut to fit within the limit and a `\n\n[Content truncated — exceeded token limit]` notice SHALL be appended. The message role and timestamp SHALL be preserved unchanged.

#### Scenario: Short message passes through unchanged
- **WHEN** a message with 100 estimated tokens is added and max_message_tokens is 30000
- **THEN** the message content is stored as-is

#### Scenario: Long message is truncated
- **WHEN** a message with 50000 estimated tokens is added and max_message_tokens is 30000
- **THEN** the stored content is cut to approximately 30000 tokens worth of characters with a truncation notice appended

#### Scenario: Truncation preserves role and timestamp
- **WHEN** a tool-role message is truncated
- **THEN** the role remains "tool" and the timestamp is unchanged

### Requirement: Pre-send context trimming
The system SHALL, before each LLM call, compute the total estimated token count of the system prompt plus all session messages. If the total exceeds `context_budget`, the system SHALL remove the oldest non-system messages (from the front of the history) until the total fits within budget. The system prompt and the most recent user message SHALL never be removed.

#### Scenario: Context within budget passes through
- **WHEN** total estimated tokens are 80000 and context_budget is 100000
- **THEN** no messages are removed

#### Scenario: Context over budget trims oldest messages
- **WHEN** total estimated tokens are 120000 and context_budget is 100000
- **THEN** the oldest messages are removed until the total is at or below 100000

#### Scenario: System prompt and latest user message are preserved
- **WHEN** context trimming is triggered
- **THEN** the system prompt is never removed and the most recent user message is always retained

#### Scenario: All messages except last user message exceed budget
- **WHEN** the system prompt plus the most recent user message alone exceed the budget
- **THEN** only the system prompt and latest user message are sent (no error, best-effort)

### Requirement: Token-aware consolidation trigger
The system SHALL trigger memory consolidation when the estimated token count of session messages exceeds 80% of `context_budget`, in addition to the existing message-count trigger. Whichever threshold is reached first SHALL trigger consolidation.

#### Scenario: Token threshold triggers consolidation before count threshold
- **WHEN** session has 30 messages (below the 50-message window) but estimated tokens exceed 80% of context_budget
- **THEN** consolidation is triggered

#### Scenario: Count threshold still triggers consolidation
- **WHEN** session has 55 messages (above the 50-message window) but estimated tokens are below 80% of context_budget
- **THEN** consolidation is triggered as before

### Requirement: Context-length error recovery
The system SHALL catch context-length-exceeded errors from the LLM API. On such an error, the system SHALL trim the oldest half of non-system messages from the conversation, then retry the LLM call exactly once. If the retry also fails, the system SHALL terminate with the error as it does today.

#### Scenario: First context-length error triggers retry
- **WHEN** the LLM API returns a context-length-exceeded error
- **THEN** the system removes the oldest 50% of non-system messages and retries the call

#### Scenario: Retry succeeds after trimming
- **WHEN** the retry call succeeds after trimming
- **THEN** the agent continues normally with the trimmed history

#### Scenario: Retry also fails
- **WHEN** the retry call also returns a context-length error
- **THEN** the agent terminates with an error as it does today (no further retries)

#### Scenario: Non-context errors are not retried
- **WHEN** the LLM API returns a rate-limit or authentication error
- **THEN** the system does not retry and terminates with the error immediately
