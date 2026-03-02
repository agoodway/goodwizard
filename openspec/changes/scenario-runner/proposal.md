### Why

Debugging the Goodwizard agent requires manually running the CLI REPL, typing queries, reading raw log files, and correlating timestamps across tools. There's no programmatic way for Claude Code to send a query to the agent, capture structured results (response, tool calls, timing, errors), and iterate on fixes. This makes agent debugging slow and error-prone — especially for multi-turn conversations where memory, session continuity, and workspace mutations interact.

### What Changes

- **New `mix goodwizard.scenario` Mix task** — CLI entry point for running scenarios. Supports inline queries (`mix goodwizard.scenario run "Hello"`) and file-based scenarios (`mix goodwizard.scenario run smoke_test`). Creates isolated temp workspaces by default, prints structured output with response text, tool calls, timing, log entries, and assertion results.

- **New `Goodwizard.Scenario.Runner` module** — Core execution engine that manages the agent lifecycle, captures tool call telemetry, buffers log entries via a custom `:logger` handler, processes multi-turn steps (queries and workspace mutations), and evaluates assertions.

- **New `Goodwizard.Scenario.LogHandler` module** — Erlang `:logger` callback that buffers log events into an Elixir Agent process during scenario execution. Scoped capture avoids ANSI parsing and race conditions with the file logger.

- **New `Goodwizard.Scenario.Loader` module** — TOML scenario file parser. Loads step-based scenarios from `priv/scenarios/`, supports query steps, setup steps (workspace mutations), and conversation replay from session JSONL files.

- **New `priv/scenarios/` directory** — Houses TOML scenario definitions. Ships with `smoke_test.toml` and `memory_continuity.toml` as starter scenarios.

### Capabilities

#### New Capabilities

- **scenario-execution**: Run queries against the full Goodwizard agent with structured result capture (response, tool calls, timing, log entries)
- **scenario-assertions**: Declarative pass/fail checks on scenario results (response content, tool usage, error absence, duration budgets)
- **multi-turn-scenarios**: Step-based scenario definitions supporting sequential queries, workspace mutations between turns, and session replay
- **scenario-log-capture**: Scoped log capture during scenario execution via custom Erlang `:logger` handler

#### Modified Capabilities

_(none — this is a new developer tooling addition with no changes to existing modules)_

### Impact

- **`lib/mix/tasks/goodwizard.scenario.ex`** — new Mix task (no changes to existing tasks)
- **`lib/goodwizard/scenario/runner.ex`** — new module
- **`lib/goodwizard/scenario/log_handler.ex`** — new module
- **`lib/goodwizard/scenario/loader.ex`** — new module
- **`priv/scenarios/`** — new directory with sample TOML files
- **Dependencies** — none new (uses existing `toml`, `telemetry`, `:logger`)
- **Supervision tree** — no changes (scenario agents are started/stopped per-run)
