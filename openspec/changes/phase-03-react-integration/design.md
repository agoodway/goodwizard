## Context

Phase 3 wires Phase 2's Jido Actions into jido_ai's ReAct tool loop. The original Nanobot had three Python modules for this: `tools/registry.py` (74 lines), `agent/context.py` (239 lines), and `agent/loop.py` (455 lines). jido_ai's `Strategies.ReAct`, `Tools.Registry`, `Executor`, and `ToolAdapter` replace the registry and loop entirely. The only custom code is `Goodwizard.ContextBuilder` — a ~150-line module that assembles workspace-aware system prompts from identity info, bootstrap files, memory, and skills.

Phase 1 (Config GenServer, Jido instance) and Phase 2 (5 Jido Actions) must be complete. No code exists yet — this is still at the planning stage.

## Goals / Non-Goals

**Goals:**
- `Goodwizard.ContextBuilder` module that assembles system prompts from workspace context
- Validation that all Phase 2 actions convert correctly via `Jido.AI.ToolAdapter.from_actions/1`
- Validation that `Jido.AI.Executor` dispatches tool calls with correct argument normalization
- Clear integration path for Phase 4 (Agent Definition) to use ReAct with these tools

**Non-Goals:**
- Agent definition or lifecycle management (Phase 4)
- CLI or channel integration (Phase 5+)
- Memory persistence or session management (Phase 6)
- Custom strategy development — we use jido_ai's ReAct as-is
- LLM provider configuration (handled by jido_ai/req_llm)

## Decisions

### 1. Single ContextBuilder module, not a behaviour/protocol

**Decision**: `Goodwizard.ContextBuilder` is a plain module with public functions, not a behaviour or GenServer.

**Rationale**: The Python `ContextBuilder` is a class but only used as a builder — no state between calls, no lifecycle management. A plain module with `build_system_prompt/2`, `build_messages/1`, `add_tool_result/4`, and `add_assistant_message/3` is the simplest Elixir equivalent. Phase 4's agent can call these functions directly when constructing prompts.

**Alternatives considered**: GenServer (unnecessary statefulness), Behaviour/Protocol (only one implementation exists, premature abstraction).

### 2. Bootstrap files read from workspace at prompt-build time

**Decision**: `build_system_prompt/2` reads bootstrap files (`AGENTS.md`, `SOUL.md`, `USER.md`, `TOOLS.md`, `IDENTITY.md`) from the workspace directory each time it's called.

**Rationale**: Bootstrap files may change between agent invocations (user edits their config). Reading at build time ensures prompts reflect the current workspace state. The file reads are cheap (small markdown files) and happen once per conversation turn, not per tool call.

**Alternatives considered**: Cache bootstrap content in ETS (premature optimization — these files are tiny and read infrequently), load once at agent start (stale content risk).

### 3. No custom tool registration — rely on ReActAgent's `tools:` option

**Decision**: Do not build a custom registry wrapper. Phase 2 actions are passed directly to `Jido.AI.ReActAgent` via the `tools:` option at agent definition time (Phase 4).

**Rationale**: jido_ai's `ReActAgent` macro accepts a `tools:` option that takes a list of action modules. Internally it uses `ToolAdapter.from_actions/1` and `Tools.Registry` to register them. Building our own registry wrapper would duplicate this. Phase 3's responsibility is validating the integration works, not wrapping it.

**Alternatives considered**: Wrapper module for registry operations — rejected because it adds indirection with no benefit when `ReActAgent` handles this automatically.

### 4. Prompt sections joined with markdown-style separators

**Decision**: System prompt sections are joined with `"\n\n---\n\n"` separators, matching the Python ContextBuilder.

**Rationale**: Clear visual separation helps LLMs parse sections. Matches existing Nanobot prompts that the LLM is trained on. Markdown `---` is universally understood as a section break.

### 5. Message format follows jido_ai's conversation structure

**Decision**: `build_messages/1` returns messages in the format expected by `Jido.AI.Conversation` — maps with `:role` and `:content` keys.

**Rationale**: jido_ai's ReAct strategy manages conversation state via `Jido.AI.Conversation`. Our message builder must produce compatible structures. Tool results use `add_tool_result/4` which wraps content in the tool-result format expected by the conversation module.

## Risks / Trade-offs

**[jido_ai API surface not fully stable]** → jido_ai 0.5.2 is pre-1.0. The `ToolAdapter`, `Executor`, and `ReAct` APIs could change. Mitigation: pin exact version, write integration tests that catch API changes early, keep our custom code (ContextBuilder) decoupled from jido_ai internals.

**[ToolAdapter parameter schema mapping]** → Jido Actions define schemas with `Jido.Action`'s DSL. `ToolAdapter.from_actions/1` must correctly map these to ReqLLM tool definitions (JSON Schema for function calling). If schema types don't map cleanly, we may need adapter code. Mitigation: Phase 3 tests verify each action's tool definition has correct name, description, and parameter_schema.

**[Executor string-to-atom key normalization]** → LLMs return JSON with string keys. `Jido.AI.Executor` normalizes these to atom keys before calling action `run/2`. If any action schema uses nested maps or lists, normalization may not be recursive. Mitigation: test with nested params (EditFile's `old_string`/`new_string` are simple strings, so low risk).

**[Bootstrap file encoding]** → Files read from workspace are assumed UTF-8. Non-UTF-8 files would cause `File.read!/1` to return raw bytes. Mitigation: use `File.read/1` (not `!`) and skip files that fail to read, logging a warning.
