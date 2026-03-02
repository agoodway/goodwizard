### Context

Goodwizard is a ReAct-based AI agent with 45+ tools, session management, long-term memory, and workspace-aware system prompts. Debugging agent behavior currently requires running the CLI REPL (`mix goodwizard.cli`), manually typing queries, and correlating raw log output in `logs/dev.log`. Claude Code has no programmatic way to run a query, inspect what tools were called, check for errors, and iterate — making the debug loop slow.

The scenario runner provides a Mix task that Claude Code can invoke via Bash, producing structured output that's both human-readable and machine-parseable. This enables a tight loop: run scenario, read output, check dev log, fix code, re-run.

### Goals

- Provide a `mix goodwizard.scenario` task that runs agent queries and returns structured results
- Support four scenario modes: sequential queries, reactive (context-dependent) queries, workspace mutations between turns, and conversation replay from session files
- Capture tool calls via telemetry and log entries via a custom `:logger` handler, scoped to the scenario run
- Support declarative assertions for automated pass/fail checks
- Run in isolated temp workspaces by default to prevent corrupting real workspace data
- Keep the implementation minimal — this is a developer debugging tool, not a test framework

### Non-Goals

- Full test framework with parallel execution, fixtures, or CI integration
- Mocking or stubbing the LLM (scenarios use real API calls)
- Performance benchmarking or load testing
- Replacing ExUnit tests for unit-level action testing
- GUI or web-based scenario editor

### Decisions

#### 1. Steps model instead of flat query list

Scenarios use an ordered list of steps, each with a `type` field (`"query"` or `"setup"`). This enables workspace mutations between agent queries — critical for testing file-dependent behaviors.

**Rationale**: Many debugging scenarios need to create/modify files between turns (e.g., "create a config file, then ask the agent to read it"). A flat query list can't express this.

**Alternative considered**: Separate `[[queries]]` and `[[setup]]` sections with ordering by index — rejected because interleaving is the natural representation and TOML `[[steps]]` handles it cleanly.

#### 2. Custom `:logger` handler instead of log file parsing

A custom Erlang `:logger` handler buffers log events into an Elixir Agent process during the scenario run. Events are collected as structured maps (`%{level, message, timestamp, module}`).

**Rationale**: Reading `logs/dev.log` would require seeking to a position before the run, parsing ANSI-colored text with timestamps, and dealing with race conditions from concurrent log writers. The custom handler gives clean structured data automatically scoped to the run window.

**Alternative considered**: Truncate log file before run, read after — rejected due to data loss risk and inability to handle concurrent scenarios.

#### 3. Telemetry for tool call capture

The runner attaches to existing `[:jido, :ai, :strategy, :react, :start|:complete|:failed]` and `[:jido, :ai, :request, :start|:complete|:failed]` telemetry events emitted by `jido_ai`. Tool calls are accumulated in an Elixir Agent process.

**Rationale**: The telemetry events already contain structured metadata (tool_name, duration_ms, iteration, request_id). This is richer and more reliable than parsing log lines.

**Alternative considered**: Parse tool log lines from the captured log entries — rejected because log formatting is lossy (params are truncated/sanitized).

#### 4. Full agent, not SubAgent

Scenarios use `Goodwizard.Agent` (the main agent) rather than `Goodwizard.SubAgent`.

**Rationale**: The purpose is to debug the real agent behavior including system prompt hydration via `TurnSetup`, all plugins (Session, Memory, PromptSkills, ScheduledTaskScheduler), and the complete 45+ tool set. SubAgent has a constrained toolset and different character setup.

#### 5. TOML for scenario files

Scenario definitions use TOML format, stored in `priv/scenarios/`.

**Rationale**: TOML is already a dependency (`toml ~> 0.7`) used for project config (`config.toml`). It handles the `[[steps]]` array-of-tables syntax naturally. Claude Code can generate TOML easily.

**Alternative considered**: Elixir term files (`.exs`) — rejected because they require `Code.eval_file` and are harder for Claude Code to generate safely. YAML — rejected because it's not a current dependency.

#### 6. Conversation replay via session JSONL

When a `[replay]` section is present, the runner loads a session JSONL file, pre-seeds the agent's session state with prior messages, and re-sends the final user message as a live query.

**Rationale**: Bug reproduction often requires the exact conversation context that triggered the issue. Session JSONL files already capture this context in the format the Session plugin expects.

### Risks / Trade-offs

- **Requires real API keys** — Scenarios make live LLM calls. No mocking support. Acceptable because the tool's purpose is debugging real agent behavior.
- **Scenario duration** — Each query takes 5-30+ seconds depending on tool calls. Multi-turn scenarios can run 1-2 minutes. Mitigated by progress output before each step.
- **Temp workspace divergence** — Temp workspaces copy bootstrap files from the real workspace but may miss custom additions. Mitigated by `--workspace` flag for real-workspace testing and `--no-cleanup` for inspection.
- **Telemetry handler leaks** — If the runner crashes without cleanup, telemetry handlers accumulate. Mitigated by `try/after` blocks and unique handler IDs.
