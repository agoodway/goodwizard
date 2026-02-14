# Phase 3: ReAct Integration

## Why

jido_ai's ReAct strategy provides a production-ready tool loop — the core LLM reason-act cycle that was going to be the most complex custom code in the project. By wiring our actions into jido_ai's tool system and using `jido_character` for structured prompt assembly, we get the entire agentic loop without writing a custom strategy and the system prompt without hand-rolling string concatenation.

This phase replaces what was originally two separate phases (ToolBuilder + ToolLoop Strategy) with integration into jido_ai's existing infrastructure, and replaces a monolithic ContextBuilder with a three-concern split: Character definition, Hydrator enrichment, and message operations.

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

### Goodwizard.Character

Module-based character definition using `jido_character`. Provides the agent's base identity as a validated, schema-backed struct instead of hand-rolled strings.

```elixir
defmodule Goodwizard.Character do
  use Jido.Character,
    name: "Goodwizard",
    role: "personal AI assistant",
    personality: %{
      traits: [:analytical, :patient, :thorough],
      values: ["accuracy", "helpfulness", "safety"]
    },
    voice: %{
      tone: :helpful,
      style: "concise technical"
    },
    instructions: [
      "Explain your reasoning before taking actions",
      "Read files before editing them",
      "Respect safety guards — never bypass pre-commit hooks or delete without confirmation",
      "Use workspace tools to interact with the filesystem",
      "When uncertain, ask for clarification rather than guessing"
    ]
end
```

Config overrides (from `[character]` TOML section) are applied at hydration time, not at module definition — the module provides defaults, the config provides user customization.

### Goodwizard.Character.Hydrator

Stateless coordinator that enriches the base character with runtime state each turn. Replaces `ContextBuilder.build_system_prompt/2`.

```elixir
defmodule Goodwizard.Character.Hydrator do
  @bootstrap_files ~w(AGENTS.md SOUL.md USER.md TOOLS.md IDENTITY.md)

  def hydrate(workspace, opts \\ [])
  # 1. Create base character from Goodwizard.Character
  # 2. Apply config overrides (if Config.get(:character) returns non-nil)
  # 3. Inject bootstrap files from workspace as knowledge (category: "workspace")
  # 4. Inject memory content as knowledge (category: "long-term-memory") — if provided in opts
  # 5. Inject skills summary as instructions — if provided in opts
  # 6. Render to ReqLLM.Context via Jido.Character.to_context/2
  # Returns {:ok, system_prompt_string}

  def inject_memory(character, memory_content)
  # Add memory as knowledge with category: "long-term-memory"
  # Uses Jido.Character.add_knowledge/3

  def inject_skills(character, skills_state)
  # Add skills summary as instruction via Jido.Character.add_instruction/2
  # Add activated skill content as knowledge with category: "active-skill"
end
```

The character is **reconstructed fresh each turn** from file-based state (not a long-lived entity). File-based memory (MEMORY.md, HISTORY.md) remains the source of truth — the character is a read-only view rendered into the system prompt.

### Goodwizard.ContextBuilder (Slimmed)

With system prompt assembly moved to Character + Hydrator, ContextBuilder is slimmed to message list operations only:

```elixir
defmodule Goodwizard.ContextBuilder do
  def build_messages(opts)
  # Build [system, ...history, user] message list
  # system_prompt comes from Hydrator.hydrate/2

  def add_tool_result(messages, tool_call_id, tool_name, result)
  def add_assistant_message(messages, content, opts \\ [])
end
```

`build_system_prompt/2` is removed — that responsibility belongs to `Hydrator.hydrate/2`.

### ReAct Strategy Configuration

The ReAct strategy handles the full tool loop. Configuration happens at the agent level (Phase 4), but this phase validates the integration works:

- Actions convert to ReqLLM tools via `Jido.AI.ToolAdapter.from_actions/1`
- ReAct's signal flow: `react.input` → LLM call → tool execution → loop → final answer
- ReAct state tracks: status, iteration count, conversation, pending tool calls, final answer
- Max iterations configurable (default 10, we'll set to 20)

### Key components being used

| Component | Replaces | Purpose |
|-----------|----------|---------|
| `Jido.AI.Tools.Registry` | ToolBuilder action map | Tool storage and lookup by name |
| `Jido.AI.Executor` | ToolBuilder.execute/4 | Execution with normalization, timeout, telemetry |
| `Jido.AI.ToolAdapter` | ToolBuilder.build_tools/2 | Action → ReqLLM tool conversion |
| `Jido.AI.Strategies.ReAct` | Strategy.ToolLoop | Full reason-act loop with state machine |
| `Jido.Character` | Hand-rolled identity string | Validated, schema-backed character definition |
| `Jido.Character.to_context/2` | String concatenation with `---` separators | Structured prompt rendering |

## Dependencies

- Phase 2 (Actions) — needs action modules to register as tools
- Phase 1 (Scaffold) — jido_character dependency and `[character]` config

## Reference

- `nanobot/agent/context.py` (239 lines)
- `nanobot/agent/tools/registry.py` (74 lines)
- `nanobot/agent/loop.py` (lines 147-263 for tool loop logic)
- jido_ai tool system guide: https://hexdocs.pm/jido_ai/readme.html
- jido_character docs: https://hexdocs.pm/jido_character/readme.html
