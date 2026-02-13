# Phase 9: Web Tools and Subagents

## Why

Web search and HTTP fetch give the agent access to live information beyond its training data. Subagents enable parallel background work — the main agent can delegate research or file processing tasks without blocking the conversation. jido_ai provides orchestration actions (`SpawnChildAgent`, `DelegateTask`) that make subagent management straightforward.

## What

### Web.Search Action

Brave Search API. Port from `nanobot/agent/tools/web.py:WebSearchTool`.

- Schema: query (required string), count (integer, default 5)
- Uses Req to call `https://api.search.brave.com/res/v1/web/search`
- Returns formatted search results

### Web.Fetch Action

HTTP fetch + content extraction. Port from `WebFetchTool`.

- Schema: url (required string), max_length (integer, default 10000)
- Fetches via Req, strips HTML tags (basic HTML-to-text), truncates

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

### Subagent.Spawn Action

Uses jido_ai's orchestration pattern:
- Schema: task (required string), context (optional string)
- Spawns SubAgent via Jido instance
- On completion, emits signal back to parent agent

### Messaging.Send Action

Cross-channel messaging:
- Schema: channel (required), chat_id (required), content (required)
- Emits directive to send message to specific channel/chat

### Tool Registration

Register new tools dynamically on the agent via `react.register_tool` signals or by adding to the agent's tools list.

## Dependencies

- Phase 4 (Agent Definition) — ReActAgent pattern for subagents

## Reference

- `nanobot/agent/tools/web.py` (~150 lines)
- `nanobot/agent/subagent.py` (~100 lines)
- jido_ai orchestration actions: SpawnChildAgent, DelegateTask
