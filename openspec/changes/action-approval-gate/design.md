## Context

Goodwizard is a ReAct-powered AI agent built on Jido. The agent has ~50 registered actions (tools) spanning shell execution, file I/O, browser automation, messaging, scheduling, and subagent spawning. Actions are invoked by the LLM during the ReAct loop — the strategy emits `ToolExec` directives which are executed via `Jido.AI.Executor`.

Currently all actions execute unconditionally once the LLM decides to call them. There is no interception layer between the LLM's tool choice and actual execution. The proposal calls for a configurable approval gate that pauses high-risk actions and asks the human operator for consent before proceeding.

**Key constraint**: Jido and jido_ai are upstream dependencies. We cannot patch them. The approval mechanism must be implemented entirely within Goodwizard's codebase.

**Execution path** (from research):
```
LLM tool_call → ReAct lift_directives → ToolExec directive → DirectiveExec → Jido.Exec.run → Action.run/2
```

The `Jido.Action` behaviour has no before/after callbacks. The `on_before_cmd` agent callback only sees ReAct-level commands (`:react_start`, `:react_llm_result`), not individual tool calls. Approval must therefore be enforced at the **action level** within Goodwizard.

## Goals / Non-Goals

**Goals:**

- Configurable list of action names that require human approval before execution
- Hard gate: protected actions physically cannot execute without a valid approval token — this is not just an LLM instruction
- Approval requests delivered to the operator's active channel (Telegram inline keyboard, CLI prompt)
- Configurable timeout with default-deny behavior
- Zero overhead for non-protected actions
- Approval context shown to operator: action name, key parameters (e.g. the shell command)

**Non-Goals:**

- Patching Jido or jido_ai
- Per-parameter approval rules (e.g. "approve shell exec only if command contains rm") — this is v2
- Approval audit log / persistence — approvals are ephemeral per-request
- Multi-approver workflows
- Approval for actions called outside the ReAct loop (e.g. ScheduledTaskRunner direct calls)

## Decisions

### 1. Hard gate via action wrapper modules

**Decision**: Replace protected actions in the agent's tool list with wrapper modules that check for a valid approval before delegating to the real action.

**Alternatives considered**:
- *LLM-directed soft gate* (system prompt says "call request_approval first"): Unreliable — LLM can skip the step. Not a real security boundary.
- *Monkey-patch executor*: Violates the "never patch deps" rule.
- *Agent on_before_cmd hook*: Doesn't see individual tool calls — only ReAct-level commands.

**Approach**: A `Goodwizard.Approval.GuardedAction` macro that generates a wrapper module. The wrapper:
1. Has the same Jido action name, description, and schema as the wrapped action
2. In `run/2`, checks `Goodwizard.Approval.Server` for a valid approval
3. If no approval exists, requests one via `Goodwizard.Approval.Server.request/3` — which blocks until the human responds or timeout
4. On approval, delegates to the real action's `run/2`
5. On denial or timeout, returns `{:error, "Action denied by operator"}`

The agent module (`Goodwizard.Agent`) reads the approval config at compile time (or startup) and swaps protected actions for their guarded wrappers in the tool list.

### 2. Approval.Server as a GenServer

**Decision**: A `Goodwizard.Approval.Server` GenServer manages pending approval requests.

**Flow**:
```
GuardedAction.run/2
  → Approval.Server.request(action_name, params_summary, channel_info)
    → Server stores pending request with unique ref
    → Server calls Approval.Notifier.notify(channel, request)
    → Server blocks (GenServer.call with timeout) waiting for response
    → Channel handler receives human response
    → Channel handler calls Approval.Server.respond(ref, :approve | :deny)
    → Server unblocks the waiting request
  ← :approved | {:denied, reason} | {:timeout, reason}
← GuardedAction proceeds or returns error
```

**Why GenServer**: The approval request originates in one process (the action execution task) and the response arrives in another (the channel handler). A GenServer bridges these two processes cleanly via `call` + `reply` semantics.

### 3. Channel notification via Approval.Notifier behaviour

**Decision**: Define an `Approval.Notifier` behaviour with `notify/2` and implement it per channel.

- **Telegram**: Send a message with inline keyboard buttons (Approve / Deny). On callback_query, call `Approval.Server.respond/2`.
- **CLI**: Print a prompt to stdout. The REPL loop detects approval-format input and calls `Approval.Server.respond/2` before passing to the agent.

The notifier is resolved at runtime based on the agent's `channel` state field (set during agent creation in each channel handler).

### 4. Configuration structure

**Decision**: New `[approval]` section in config.toml:

```toml
[approval]
enabled = true
timeout = 60               # seconds to wait for human response
default = "deny"           # "deny" or "approve" on timeout
actions = ["exec", "spawn_subagent", "send_message"]
```

- `actions` uses Jido action **names** (the `name:` field from `use Jido.Action`), not module names
- `enabled = false` disables the gate entirely — all actions execute normally
- Config is read at agent startup to build the guarded tool list

### 5. Approval request contains action context

**Decision**: The approval prompt shown to the human includes the action name and a summary of key parameters, so the operator can make an informed decision.

Each guarded action can optionally define a `summarize_params/1` function that extracts the relevant fields. Default: show all params truncated to 200 chars.

Example Telegram prompt:
```
🔒 Approval Required

Action: exec
Command: rm -rf /tmp/old-cache
Timeout: 60s

[✅ Approve]  [❌ Deny]
```

## Risks / Trade-offs

**[Blocking the ReAct loop]** → The approval wait happens inside action execution, which runs in a Task spawned by the ToolExec directive handler. The ReAct loop is blocked waiting for the tool result. This is acceptable because:
- The agent cannot meaningfully continue without the tool result
- Timeout ensures the block is bounded
- The human is actively prompted, so response time is typically seconds

**[Channel identification]** → The guarded action needs to know which channel to notify. The action `context` map includes `agent_id` (e.g. `"telegram:12345"` or `"cli:direct:1"`), from which the channel type can be inferred. Risk: if agent_id format changes. Mitigation: also store `channel` in agent state and pass via tool_context.

**[Macro complexity]** → The `GuardedAction` macro must faithfully replicate the wrapped action's Jido metadata (name, description, schema). Risk: drift if the wrapped action changes. Mitigation: the macro reads metadata from the wrapped module at compile time using `__action_metadata__/0` or the module's `@action_*` attributes.

**[CLI approval UX]** → The CLI REPL runs a blocking `IO.gets` loop. An approval prompt arriving mid-turn means the user sees the prompt interleaved with the REPL. This is acceptable for CLI (power-user channel). The approval prompt prints clearly and the user types `y` or `n`.

**[Telegram callback_query routing]** → Telegram inline keyboard responses arrive as `callback_query` updates, not regular messages. The Telegram handler must handle this update type and route to `Approval.Server`. This requires extending the Telegex handler, which currently only processes text messages.
