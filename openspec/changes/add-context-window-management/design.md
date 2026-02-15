## Context

Goodwizard's agent sends conversation history to the LLM with no token-awareness. The only protection is a 200-message hard cap in `Session` and a 50-message consolidation trigger in `Agent.maybe_consolidate/1`. Long messages (file reads, tool outputs) can exceed model context limits well before hitting these count thresholds. When the LLM API returns a context-length error, the agent terminates with no recovery.

Key files:
- `lib/goodwizard/agent.ex` — `on_before_cmd` (consolidation + prompt hydration), `on_after_cmd` (session recording)
- `lib/goodwizard/plugins/session.ex` — `add_message/4` (200-message cap), `get_history/2`
- `lib/goodwizard/config.ex` — defaults map, `@numeric_ranges` validation
- `lib/goodwizard/actions/memory/consolidate.ex` — LLM-driven consolidation

The agent uses Jido's ReAct strategy. Messages flow through `Jido.AI.Thread` to `ReqLLM.stream_text/3`. Neither Jido nor ReqLLM performs token counting or truncation.

## Goals / Non-Goals

**Goals:**
- Prevent context-length API errors in normal operation through proactive budget enforcement
- Truncate oversized individual messages (file reads, tool output) at ingestion time
- Trigger consolidation based on token pressure, not just message count
- Recover gracefully from context-length errors with a single trim-and-retry
- Keep the implementation dependency-free (no external tokenizer)

**Non-Goals:**
- Exact token counting (a character-ratio heuristic is sufficient for safety margins)
- Modifying Jido or ReqLLM internals — all changes stay in Goodwizard's layer
- Per-model context window detection (use a single configurable budget)
- Caching token counts (premature — can add later via `Goodwizard.Cache` if profiling shows need)

## Decisions

### 1. New module: `Goodwizard.ContextWindow`

A pure-functional module with no GenServer state. Functions:

- `estimate_tokens(text)` — `ceil(String.length(text) / 4)`. The ÷4 ratio is a well-known approximation for English text with Claude/GPT tokenizers. Overestimates slightly, which is the safe direction.
- `estimate_tokens(messages)` when is_list — sums estimates across all message contents.
- `trim_to_budget(messages, system_prompt, budget)` — drops oldest non-system messages from the front until total fits. Always preserves the last message (most recent user query).
- `truncate_message(content, max_tokens)` — slices content to `max_tokens * 4` characters and appends a truncation notice. Returns content unchanged if within limit.

**Why a separate module instead of inline in Agent?** Testability. Pure functions with no side effects are trivial to unit test. Agent integration is a thin wrapper.

**Why not use a tokenizer library?** Adds a dependency (Rust NIF or large vocab file) for marginal accuracy gain. The heuristic overestimates by ~10-20%, which provides a safety buffer. If precision matters later, swap the implementation inside `estimate_tokens/1`.

### 2. Per-message truncation in `Session.add_message/4`

Insert truncation before appending to the messages list. This catches oversized content at ingestion regardless of source (file reads, tool output, user input). The truncation limit comes from `Goodwizard.Config.get(["agent", "max_message_tokens"])` with a fallback default.

**Why at ingestion, not at send time?** Truncating early means the session never stores bloated messages, keeping persistence files smaller and consolidation prompts manageable. The original content is already lost (not stored elsewhere), so there's no benefit to deferring.

### 3. Pre-send trimming in `Agent.on_before_cmd/2`

After consolidation check and before system prompt injection, compute total estimated tokens (system prompt + all session messages). If over budget, drop oldest messages from the front. This runs every turn, so it's the primary safety net.

Integration point: between `maybe_consolidate(agent)` (line 68) and system prompt hydration (line 71) in `on_before_cmd`. Add a new `maybe_trim_context(agent, system_prompt)` call after hydration that trims session messages against the budget minus the system prompt's token cost.

Revised flow in `on_before_cmd`:
1. `maybe_consolidate(agent)` — existing, now also token-aware
2. Build system prompt via Hydrator
3. `maybe_trim_context(agent, system_prompt)` — new, trims session if over budget
4. Inject system prompt into action params

### 4. Token-aware consolidation trigger

Extend `maybe_consolidate/1` to also check estimated tokens against 80% of `context_budget`. The 80% threshold provides a buffer — consolidation fires before we're critically close to the limit.

```
consolidation_needed =
  length(messages) > memory_window or
  estimate_tokens(messages) > context_budget * 0.8
```

This is additive — the existing count-based trigger continues to work.

### 5. Context-length error recovery

This lives in `Agent` as a wrapper around the ReAct execution. Since Jido's ReAct machine handles LLM calls internally via directives, and error handling happens in the machine's `handle_llm_response/1`, the cleanest integration point is to detect the error after a query completes with a context-length failure, trim, and re-invoke.

Approach: In `on_after_cmd`, if the agent terminated with a context-length error:
1. Trim the oldest 50% of non-system messages from the session
2. Set a `:context_retry` flag in state
3. Re-invoke the query

The `:context_retry` flag prevents infinite loops — if it's already set when an error occurs, terminate normally.

**Alternative considered: patching Jido's directive layer.** Rejected — modifying framework internals is fragile and harder to maintain across Jido upgrades.

### 6. Config additions

Add to `@defaults` in `config.ex`:
```elixir
"context_budget" => 100_000,
"max_message_tokens" => 30_000
```

Add to `@numeric_ranges`:
```elixir
{["agent", "context_budget"], 1_000, 1_000_000},
{["agent", "max_message_tokens"], 100, 200_000}
```

Default of 100k tokens is conservative for Claude Sonnet (200k context). Leaves ~100k for the response + safety margin. Users on smaller models can lower it.

## Risks / Trade-offs

**Character-ratio estimation is imprecise** → Overestimates by ~10-20% for English, more for code with short tokens. This means we trim earlier than strictly necessary. Mitigation: the budget default (100k) is already half the model's actual limit, so overestimation adds safety rather than causing problems.

**Per-message truncation loses data permanently** → Unlike pre-send trimming (which only affects what the LLM sees), truncation at ingestion modifies the stored session. Mitigation: only applied to messages exceeding 30k tokens (~120k characters), which is an extraordinary amount of content. The truncation notice makes it visible.

**Error recovery retry adds latency** → A failed + retried LLM call doubles response time for that turn. Mitigation: this is a last-resort path that should rarely trigger if pre-send trimming works correctly. One retry is better than a hard failure.

**Consolidation at 80% budget may fire too often with large system prompts** → If the system prompt is 20k tokens, the effective message budget is only 60k tokens (80% of 100k minus prompt). Mitigation: configurable budget allows tuning per deployment. The 80% threshold can be adjusted if needed.

**No per-model context window detection** → A user switching to a smaller model (e.g., Haiku with 200k, or an Ollama model with 8k) must manually adjust `context_budget`. Mitigation: document this in config.toml comments. Auto-detection would require maintaining a model→context-size mapping that's fragile and out of scope for this change.
