# Phase 3: ReAct Integration

## Why

jido_ai's ReAct strategy provides a production-ready tool loop — the core LLM reason-act cycle that was going to be the most complex custom code in the project. By wiring our actions into jido_ai's tool system and building a ContextBuilder for system prompt assembly, we get the entire agentic loop without writing a custom strategy.

This phase replaces what was originally two separate phases (ToolBuilder + ToolLoop Strategy) with integration into jido_ai's existing infrastructure.

## What

### Tool Registration

Register all Phase 2 actions in jido_ai's tool system. The `Jido.AI.ToolAdapter` converts Jido Actions to ReqLLM tool format automatically. The `Jido.AI.Tools.Registry` provides lookup by name, and `Jido.AI.Executor` handles argument normalization (string keys → atom keys) and execution.

```elixir
# Actions register automatically when passed to ReActAgent's tools: option
# Manual registration also available:
Jido.AI.Tools.Registry.register_actions([
  Goodwizard.Actions.Filesystem.ReadFile,
  Goodwizard.Actions.Filesystem.WriteFile,
  Goodwizard.Actions.Filesystem.EditFile,
  Goodwizard.Actions.Filesystem.ListDir,
  Goodwizard.Actions.Shell.Exec
])
```

### ContextBuilder

Port of `nanobot/agent/context.py:ContextBuilder` (239 lines). This is the one piece jido_ai doesn't provide — workspace-aware system prompt assembly.

```elixir
defmodule Goodwizard.ContextBuilder do
  @bootstrap_files ~w(AGENTS.md SOUL.md USER.md TOOLS.md IDENTITY.md)

  def build_system_prompt(workspace, opts \\ [])
  # 1. Core identity section (name, current time, runtime info, workspace path)
  # 2. Bootstrap files from workspace if they exist
  # 3. Memory context (if provided in opts)
  # 4. Skills summary (if provided in opts)
  # Join with "\n\n---\n\n"

  def build_messages(opts)
  # Build [system, ...history, user] message list

  def add_tool_result(messages, tool_call_id, tool_name, result)
  def add_assistant_message(messages, content, opts \\ [])
end
```

### ReAct Strategy Configuration

The ReAct strategy handles the full tool loop. Configuration happens at the agent level (Phase 4), but this phase validates the integration works:

- Actions convert to ReqLLM tools via `Jido.AI.ToolAdapter.from_actions/1`
- ReAct's signal flow: `react.input` → LLM call → tool execution → loop → final answer
- ReAct state tracks: status, iteration count, conversation, pending tool calls, final answer
- Max iterations configurable (default 10, we'll set to 20)

### Key jido_ai components being used

| Component | Replaces | Purpose |
|-----------|----------|---------|
| `Jido.AI.Tools.Registry` | ToolBuilder action map | Tool storage and lookup by name |
| `Jido.AI.Executor` | ToolBuilder.execute/4 | Execution with normalization, timeout, telemetry |
| `Jido.AI.ToolAdapter` | ToolBuilder.build_tools/2 | Action → ReqLLM tool conversion |
| `Jido.AI.Strategies.ReAct` | Strategy.ToolLoop | Full reason-act loop with state machine |

## Dependencies

- Phase 2 (Actions) — needs action modules to register as tools

## Reference

- `nanobot/agent/context.py` (239 lines)
- `nanobot/agent/tools/registry.py` (74 lines)
- `nanobot/agent/loop.py` (lines 147-263 for tool loop logic)
- jido_ai tool system guide: https://hexdocs.pm/jido_ai/readme.html
- jido_ai strategies guide: https://hexdocs.pm/jido_ai/readme.html
