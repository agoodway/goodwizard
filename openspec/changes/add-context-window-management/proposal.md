## Why

Goodwizard has no token-aware context window management. The only protection is a message-count consolidation trigger (default 50 messages), but long messages — large file reads, verbose tool outputs, multi-step ReAct chains — can exceed the LLM's context limit well before hitting the count threshold. When the API returns a context-length error, the agent terminates with no retry or recovery. This needs fixing before users hit it in real workflows.

## What Changes

- Add a token estimation utility that approximates token counts for messages without requiring a tokenizer dependency
- Add a context budget manager that tracks cumulative token usage across system prompt, conversation history, and tool definitions, and enforces a configurable ceiling
- Add pre-send context trimming that intelligently truncates the oldest non-system messages when the budget is exceeded, preserving the system prompt and most recent exchange
- Add large-message truncation for individual messages (e.g. file read results) that exceed a per-message token threshold, with a truncation notice appended
- Add context-length error recovery so that when the LLM API returns a context-overflow error, the agent trims history and retries once instead of terminating
- Add configurable limits (`context_budget`, `max_message_tokens`) in `config.toml` under `[agent]`

## Capabilities

### New Capabilities

- `context-window`: Token estimation, budget tracking, pre-send trimming, per-message truncation, and error recovery for LLM context windows

### Modified Capabilities

None — no existing specs to modify.

## Impact

- **lib/goodwizard/context_window.ex** (new) — token estimation and budget/trimming logic
- **lib/goodwizard/agent.ex** — integrate pre-send trimming in `on_before_cmd`, add error recovery path
- **lib/goodwizard/config.ex** — new default keys for `context_budget` and `max_message_tokens`
- **lib/goodwizard/plugins/session.ex** — per-message truncation on `add_message`
- **lib/goodwizard/actions/memory/consolidate.ex** — may need to trigger consolidation earlier when token budget is tight (not just message count)
- No new dependencies — token estimation uses a character-ratio heuristic, no external tokenizer
- No breaking changes to existing APIs or channel behavior
