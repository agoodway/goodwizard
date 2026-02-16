## Why

Goodwizard can execute shell commands, spawn subagents, write files, and interact with external services autonomously. Some of these actions carry real-world consequences — a shell `rm`, an outbound message, or a spawned subagent running unchecked. There is currently no mechanism to pause execution and ask the human operator for approval before a high-risk action proceeds. Adding a human-in-the-loop gate gives the operator control over which actions require explicit consent before execution, without disrupting the flow of low-risk operations.

## What Changes

- Introduce a configurable approval gate that intercepts designated actions before execution and requests human approval via the active channel (Telegram, CLI)
- Add an `approval` config section where operators list action names (or patterns) that require approval, plus timeout and default-deny behavior
- Build an approval request/response flow: the agent pauses, sends an approval prompt to the operator's channel, waits for an approve/deny response within a timeout, then either proceeds or returns an error
- Actions not in the approval list execute normally with zero overhead
- The agent's ReAct loop must handle the pause gracefully — the approval wait happens inside the action execution, not at the LLM planning layer

## Capabilities

### New Capabilities

- `action-approval`: The approval gate mechanism — config-driven action interception, approval request delivery via channels, response collection with timeout, and approve/deny/timeout handling

### Modified Capabilities

_(none — this is additive and does not change existing action or channel specs)_

## Impact

- **Actions layer** (`lib/goodwizard/actions/`): Approval check wraps action execution; individual actions are not modified
- **Channels** (`lib/goodwizard/channels/`): Telegram and CLI handlers need to support inline approval prompts (approve/deny buttons or text responses) outside the normal ReAct conversational flow
- **Config** (`lib/goodwizard/config.ex`, `config.toml`, `mix goodwizard.setup`): New `[approval]` config section with action list, timeout, and default behavior
- **Agent** (`lib/goodwizard/agent.ex`): Minimal — the gate operates at the action execution boundary, not in the ReAct loop itself
- **Dependencies**: No new external dependencies expected; uses existing messaging/delivery infrastructure
