## Context

Phase 9 adds browser capabilities and subagent orchestration to the Goodwizard agent. Browser capabilities are provided entirely by `jido_browser` via its Plugin pattern — no custom web action modules needed. The SubAgent module uses `Jido.AI.ReActAgent` to run focused background tasks. Cross-channel messaging enables the agent to send messages to other channels (e.g., Telegram from CLI).

Phases 1–4 must be complete: the Mix project scaffold (including jido_browser dependency and browser config), Jido Actions framework, Tool Registry, and the main ReActAgent are prerequisites. Phase 5 (CLI channel) or Phase 8 (Telegram channel) provide the messaging targets.

## Goals / Non-Goals

**Goals:**
- JidoBrowser.Plugin mounted on the agent with 31 browser actions auto-registered
- Browser config wired from Goodwizard.Config to `:jido_browser` application env
- 1 subagent module: `Goodwizard.SubAgent` with limited tool access (no browser plugin)
- 1 spawn action: `Subagent.Spawn` to start background agents with task delegation
- 1 messaging action: `Messaging.Send` for cross-channel message emission
- Register subagent and messaging actions on the main agent's tool list

**Non-Goals:**
- Subagent-to-subagent communication (no recursive spawning)
- Persistent subagent processes (subagents complete their task and stop)
- Rate limiting or API quota management for Brave Search
- Custom browser adapter implementations beyond Vibium and Web

## Decisions

### 1. JidoBrowser.Plugin for all browser/web capabilities

**Decision**: Use `JidoBrowser.Plugin` to provide all browser and web capabilities. The plugin registers 31 actions automatically via `mount/2`, manages session lifecycle, provides signal routing for `browser.*` patterns, and includes error diagnostics with page context.

**Rationale**: Same agentjido ecosystem as jido/jido_ai. Eliminates custom `Web.Search` and `Web.Fetch` action modules. Provides proper HTML-to-markdown conversion (not lossy regex stripping), full browser automation (click, type, screenshot, JS execution), and self-contained actions like `ReadPage` and `SearchWeb` that manage their own sessions. Zero custom web code needed.

**Alternatives considered**: Custom Jido Actions using Req for HTTP — rejected because jido_browser provides all this plus browser automation for free. Wallaby — Elixir browser testing library, not designed for agent tool use.

### 2. Vibium as default browser adapter

**Decision**: Use Vibium as the default browser adapter for jido_browser.

**Rationale**: Vibium uses the WebDriver BiDi protocol and auto-manages its Chrome binary (~10MB, downloaded at install via `mix jido_browser.install`). Headless by default, which is appropriate for an agent that doesn't need a visible browser window. The Web adapter (Firefox, HTML-to-markdown via chrismccord/web) is available as an alternative via the `browser.adapter` config key.

**Alternatives considered**: Web adapter as default — provides Firefox and different HTML conversion, but Vibium's Chrome-based approach is more widely compatible and the BiDi protocol is more capable.

### 3. Plugin session injection via `on_before_cmd`

**Decision**: The browser plugin state (including session) is available to actions through `tool_context`. The agent's `on_before_cmd/2` callback passes plugin state to actions that need it.

**Rationale**: Self-contained actions (ReadPage, SearchWeb, SnapshotUrl) manage their own sessions and don't need injected state. Session-based actions (Navigate, Click, Type) require an active session from StartSession. The plugin manages this lifecycle — no custom session management code needed in Goodwizard.

### 4. SubAgent uses ReActAgent with restricted tools

**Decision**: `Goodwizard.SubAgent` uses `Jido.AI.ReActAgent` with only filesystem and shell tools. No `Subagent.Spawn`, `Messaging.Send`, or browser plugin in its tool list.

**Rationale**: Prevents recursive spawning (subagent spawning subagents) and uncontrolled message sending. The subagent is a focused worker for file processing, code analysis, or research tasks. The parent agent orchestrates. No browser plugin on the subagent keeps it lightweight and focused.

### 5. Subagent runs as a Task, not a persistent process

**Decision**: `Subagent.Spawn` starts the subagent as an Elixir Task. The parent agent receives the result when the task completes.

**Rationale**: Subagents are short-lived — they complete a task and return results. A Task is the simplest concurrency primitive for this. No need for GenServer lifecycle management. If the parent dies, the linked task dies too (no orphans).

**Alternatives considered**: GenServer-based subagent — overkill for fire-and-forget tasks. DynamicSupervisor — adds complexity without clear benefit since subagents don't need restart semantics.

### 6. Messaging.Send uses room_id API via Goodwizard.Messaging

**Decision**: `Messaging.Send` uses `room_id + content` schema. It saves the message via `Goodwizard.Messaging.save_message/1` for persistence and uses `JidoMessaging.Deliver` for external delivery to bound channels.

**Rationale**: The room_id abstraction decouples the action from specific channel implementations. Rooms are created with external bindings (e.g., `{:telegram, bot, chat_id}`) by the Ingest pipeline. `Messaging.Send` doesn't need to know the channel type — it targets a room, and jido_messaging handles delivery to whatever channel the room is bound to. This also provides message persistence for free.

### 7. Brave Search API key from Config

**Decision**: Read the Brave Search API key from `Goodwizard.Config.get([:browser, :search, :brave_api_key])` and wire it into `:jido_browser` application config as `:brave_search_api_key` at startup.

**Rationale**: Consistent with Phase 1's config pattern. The key can be set via `config.toml` `[browser.search]` section or `BRAVE_API_KEY` environment variable. jido_browser's `SearchWeb` action reads the key from its own application config, so the wiring happens once at startup.

## Risks / Trade-offs

**[Browser binary size]** → The Vibium browser binary is ~10MB, downloaded at install time via `mix jido_browser.install`. This is a one-time download but adds to the project's setup requirements. Mitigation: document in Phase 1 config, make it a compile-time task.

**[Brave Search has rate limits]** → Free tier allows 2,000 queries/month. No rate limiting implemented in this phase. Risk of 429 errors under heavy use. Mitigation: jido_browser returns the error to the agent so it can reason about it.

**[Subagent model cost]** → Each subagent spawn creates a new ReActAgent conversation with its own LLM calls. Could be expensive if the parent agent spawns many subagents. Mitigation: max_iterations cap of 10 on subagents, and the parent agent's prompt should guide judicious use.

**[Cross-channel messaging delivery]** → `Messaging.Send` persists messages via `Goodwizard.Messaging.save_message/1` and uses `JidoMessaging.Deliver` for external delivery. Messages are always persisted in the room even if external delivery fails. jido_messaging provides delivery tracking for bound channels.
