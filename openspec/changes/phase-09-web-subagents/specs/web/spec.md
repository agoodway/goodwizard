## ADDED Requirements

### Requirement: JidoBrowser.Plugin registered on agent
The agent SHALL include `JidoBrowser.Plugin` in its plugins configuration with headless mode enabled. The plugin provides 31 browser automation actions via the Jido Plugin pattern.

#### Scenario: Plugin mounts with browser state
- **WHEN** the agent is instantiated with `plugins: [{JidoBrowser.Plugin, [headless: true]}]`
- **THEN** `state.browser` SHALL contain session, headless, timeout, adapter, and viewport configuration

#### Scenario: Plugin registers browser actions
- **WHEN** the plugin mounts on the agent
- **THEN** the ToolAdapter SHALL produce tool definitions for all 31 actions including: StartSession, EndSession, Navigate, Click, Type, Hover, Screenshot, ReadPage, SearchWeb, SnapshotUrl, ExtractContent, EvaluateJavascript, and others

#### Scenario: Signal routes wired
- **WHEN** the plugin mounts on the agent
- **THEN** signals matching the `browser.*` pattern SHALL route to the corresponding browser actions

### Requirement: Browser config wired from Goodwizard.Config
On application startup, `Goodwizard.Config` SHALL write browser settings to the `:jido_browser` application config.

#### Scenario: Brave API key wired
- **WHEN** `Config.get([:browser, :search, :brave_api_key])` returns `"my-key"`
- **THEN** `Application.get_env(:jido_browser, :brave_search_api_key)` SHALL return `"my-key"`

#### Scenario: Adapter wired
- **WHEN** `Config.get([:browser, :adapter])` returns `"vibium"`
- **THEN** the application config SHALL map `"vibium"` to `JidoBrowser.Adapters.Vibium`

#### Scenario: Adapter wired as Web
- **WHEN** `Config.get([:browser, :adapter])` returns `"web"`
- **THEN** the application config SHALL map `"web"` to `JidoBrowser.Adapters.Web`

#### Scenario: Missing Brave API key
- **WHEN** `SearchWeb` is called and the Brave API key is not configured
- **THEN** it SHALL return an error indicating the API key is not configured (handled by jido_browser internally)

### Requirement: Self-contained actions work without explicit session
`ReadPage`, `SnapshotUrl`, and `SearchWeb` SHALL manage their own browser sessions internally. No prior `StartSession` call is required.

#### Scenario: ReadPage fetches and extracts
- **WHEN** `ReadPage` is called with `url: "https://example.com"`
- **THEN** it SHALL return markdown content extracted from the page, with the session auto-started and auto-closed

#### Scenario: SearchWeb queries Brave
- **WHEN** `SearchWeb` is called with `query: "elixir genserver"`
- **THEN** it SHALL return ranked results with title, URL, and snippet for each result

#### Scenario: SnapshotUrl captures page
- **WHEN** `SnapshotUrl` is called with `url: "https://example.com"`
- **THEN** it SHALL return an LLM-optimized page snapshot

### Requirement: Session-based actions require explicit session
Actions like Navigate, Click, Type, Hover, and Screenshot SHALL require an active session via `StartSession` before use.

#### Scenario: Navigate without session returns error
- **WHEN** `Navigate` is called without a prior `StartSession`
- **THEN** it SHALL return an actionable error message about needing to start a session first

#### Scenario: Multi-step browsing flow
- **WHEN** the agent executes `StartSession` → `Navigate` → `Click` → `ExtractContent` → `EndSession`
- **THEN** each action SHALL execute successfully in sequence, sharing the same browser session
