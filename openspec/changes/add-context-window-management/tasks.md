## 1. Config

- [ ] 1.1 Add `context_budget` (default 100000) and `max_message_tokens` (default 30000) to `@defaults` in `lib/goodwizard/config.ex`
- [ ] 1.2 Add numeric range validations for both new keys to `@numeric_ranges` in `lib/goodwizard/config.ex`
- [ ] 1.3 Add tests for default values and out-of-range fallback in `test/goodwizard/config_test.exs`

## 2. ContextWindow module

- [ ] 2.1 Create `lib/goodwizard/context_window.ex` with `estimate_tokens/1` for strings (chars ÷ 4, ceil)
- [ ] 2.2 Add `estimate_tokens/1` clause for list of message maps (sum of content estimates)
- [ ] 2.3 Add `truncate_message/2` that slices content to `max_tokens * 4` chars and appends truncation notice, returns unchanged if within limit
- [ ] 2.4 Add `trim_to_budget/3` that drops oldest non-system messages until total fits within budget, always preserving the last message
- [ ] 2.5 Add unit tests in `test/goodwizard/context_window_test.exs` covering all spec scenarios: empty string, single string, message list, truncation, budget trimming edge cases

## 3. Per-message truncation

- [ ] 3.1 Modify `Session.add_message/4` in `lib/goodwizard/plugins/session.ex` to truncate message content via `ContextWindow.truncate_message/2` before appending, using `max_message_tokens` from Config with fallback default
- [ ] 3.2 Add tests in `test/goodwizard/plugins/session_test.exs` for short message passthrough and long message truncation with notice

## 4. Pre-send context trimming

- [ ] 4.1 Add `maybe_trim_context/2` private function to `lib/goodwizard/agent.ex` that estimates tokens for system prompt + session messages and calls `ContextWindow.trim_to_budget/3` when over `context_budget`
- [ ] 4.2 Integrate `maybe_trim_context/2` into `on_before_cmd` after system prompt hydration (between line 89 and line 96)
- [ ] 4.3 Add tests in `test/goodwizard/agent_test.exs` verifying trimming fires when over budget and no-ops when under

## 5. Token-aware consolidation

- [ ] 5.1 Extend `maybe_consolidate/1` in `lib/goodwizard/agent.ex` to also trigger when `ContextWindow.estimate_tokens(messages)` exceeds 80% of `context_budget`, in addition to the existing count check
- [ ] 5.2 Add test verifying consolidation triggers on token pressure even when message count is below window

## 6. Context-length error recovery

- [ ] 6.1 Add `handle_context_length_error/2` to `lib/goodwizard/agent.ex` that trims oldest 50% of non-system messages and sets `:context_retry` flag in state
- [ ] 6.2 Integrate error detection in `on_after_cmd` — when agent terminates with a context-length error and `:context_retry` is not set, invoke recovery; if already set, propagate the error
- [ ] 6.3 Add tests for retry-on-first-error, no-retry-on-second-error, and non-context-errors-not-retried

## 7. Verification

- [ ] 7.1 Run `mix compile --warnings-as-errors`
- [ ] 7.2 Run `mix format --check-formatted`
- [ ] 7.3 Run `mix test` and verify no new failures
