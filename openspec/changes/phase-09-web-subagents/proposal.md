# Phase 9: Browser Capabilities and Subagents

## Why

Browser capabilities give the agent access to live information beyond its training data — web search, page reading, and full browser automation. Subagents enable parallel background work — the main agent can delegate research or file processing tasks without blocking the conversation. The `jido_browser` library (`~> 0.8`) from the agentjido ecosystem provides all browser capabilities through a Plugin pattern, registering 31 browser automation actions automatically. jido_ai provides orchestration actions (`SpawnChildAgent`, `DelegateTask`) that make subagent management straightforward.

## What

### JidoBrowser.Plugin Integration

The agent includes `JidoBrowser.Plugin` in its plugins configuration, which automatically registers 31 browser actions covering:

- **Session lifecycle**: StartSession, EndSession, ResetSession
- **Navigation**: Navigate, NavigateBack, NavigateForward, Reload
- **Interaction**: Click, Type, Hover, SelectOption, DragAndDrop, PressKey
- **Synchronization**: WaitForElement, WaitForNavigation, WaitForTimeout
- **Content extraction**: ExtractContent, ExtractStructuredData, EvaluateJavascript
- **Advanced**: Screenshot, SnapshotUrl, FillForm, FileUpload, HandleDialog

Key self-contained actions (manage their own session, no StartSession needed):
- **ReadPage** — fetch a URL and extract content as markdown. Self-contained: starts session, fetches, extracts, closes session.
- **SearchWeb** — query Brave Search API. Returns ranked results with title, URL, and snippet. Requires `BRAVE_API_KEY` configured.
- **SnapshotUrl** — capture an LLM-optimized page snapshot. Self-contained session management.

### Goodwizard.SubAgent

Focused agent for background tasks using jido_ai's ReActAgent with limited tools (no spawn, no messaging to prevent recursion):

```elixir
defmodule Goodwizard.SubAgent do
  use Jido.AI.ReActAgent,
    name: "goodwizard_subagent",
    description: "Focused background agent",
    tools: [
      Goodwizard.Actions.Filesystem.ReadFile,
      Goodwizard.Actions.Filesystem.WriteFile,
      Goodwizard.Actions.Filesystem.ListDir,
      Goodwizard.Actions.Shell.Exec
    ],
    model: "anthropic:claude-sonnet-4-5",
    max_iterations: 10
end
```

### Goodwizard.SubAgent.Character

The subagent gets its own character module with a focused identity and constrained instructions:

```elixir
defmodule Goodwizard.SubAgent.Character do
  use Jido.Character,
    name: "Goodwizard SubAgent",
    role: "background research and file processing agent",
    personality: %{
      traits: [:focused, :efficient, :thorough],
      values: ["accuracy", "completeness"]
    },
    voice: %{
      tone: :professional,
      style: "concise and factual"
    },
    instructions: [
      "Complete the assigned task and report results",
      "Do not communicate directly with the user",
      "Do not spawn additional subagents",
      "Stay within the scope of the delegated task",
      "Read files before modifying them"
    ]
end
```

The SubAgent's `on_before_cmd/2` uses this character with the delegated task context injected as knowledge (category: "task-context") via the Hydrator.

### Subagent.Spawn Action

Uses jido_ai's orchestration pattern:
- Schema: task (required string), context (optional string)
- Spawns SubAgent via Jido instance
- On completion, emits signal back to parent agent

### Messaging.Send Action

Cross-channel messaging via Goodwizard.Messaging:
- Schema: room_id (required), content (required)
- Saves the message via `Goodwizard.Messaging.save_message/1` for persistence
- Uses `JidoMessaging.Deliver` for external delivery to bound channels (e.g., Telegram rooms)

### Tool Registration

Browser actions are auto-registered by JidoBrowser.Plugin — no individual `Goodwizard.Actions.Web.*` modules needed. Subagent and messaging actions are registered on the agent's tools list. Note the Messaging.Send schema uses `room_id + content` (not `channel + chat_id`).

## Dependencies

- Phase 4 (Agent Definition) — ReActAgent pattern for subagents
- Phase 1 (Scaffold & Config) — browser config and jido_browser dependency

## Reference

- jido_browser docs: https://hexdocs.pm/jido_browser/readme.html
- jido_ai orchestration actions: SpawnChildAgent, DelegateTask
