### 1. Log Handler

- [x] 1.1 Create `lib/goodwizard/scenario/log_handler.ex` — Erlang `:logger` callback module with `log/2` that buffers events to an Agent process. Handle `{:string, _}`, `{:report, _}`, and binary message formats.
- [x] 1.2 Write tests for LogHandler in `test/goodwizard/scenario/log_handler_test.exs` — verify event buffering, message format handling, and level capture.

### 2. Scenario Loader

- [x] 2.1 Create `lib/goodwizard/scenario/loader.ex` — `load/1` reads and parses `priv/scenarios/{name}.toml`, normalizes to scenario map with steps, assertions, and optional replay config. `list/0` returns available scenario names.
- [x] 2.2 Create `priv/scenarios/` directory.
- [x] 2.3 Create `priv/scenarios/smoke_test.toml` — single query "Hello, who are you?" with `response_contains` and `no_errors` assertions.
- [x] 2.4 Create `priv/scenarios/memory_continuity.toml` — multi-turn: tell name, check recall, with setup step between turns.
- [x] 2.5 Write tests for Loader in `test/goodwizard/scenario/loader_test.exs` — verify TOML parsing, step normalization, assertion loading, list function, and error handling for missing/invalid files.

### 3. Scenario Runner

- [x] 3.1 Create `lib/goodwizard/scenario/runner.ex` — define `ToolCall`, `QueryResult`, and `Result` structs.
- [x] 3.2 Implement telemetry collector — `start_telemetry_collector/0` attaches to `[:jido, :ai, :strategy, :react, *]` and `[:jido, :ai, :request, *]` events, `collect_tool_calls/1` retrieves accumulated calls. Use unique handler IDs via `System.unique_integer/1`.
- [x] 3.3 Implement log capture integration — `start_log_capture/0` installs LogHandler, `collect_log_entries/1` retrieves buffered entries.
- [x] 3.4 Implement `execute/1` — orchestrates agent lifecycle (start → query steps → stop), processes query and setup steps, wraps in `try/after` for cleanup.
- [x] 3.5 Implement setup step processing — `write_file` creates file in workspace, `delete_file` removes it.
- [x] 3.6 Implement conversation replay — load session JSONL via `Goodwizard.Plugins.Session`, pre-seed agent session state, send final user message.
- [x] 3.7 Implement assertion evaluator — `evaluate_assertions/2` handles all assertion types: `response_contains`, `response_not_contains`, `no_errors`, `no_warnings`, `tool_called`, `tool_not_called`, `max_duration_ms`, `max_tool_calls`.
- [x] 3.8 Write tests for Runner in `test/goodwizard/scenario/runner_test.exs` — test telemetry collector, log capture, assertion evaluator, and setup step processing. Mark integration tests that require LLM with `@tag :llm`.

### 4. Mix Task

- [x] 4.1 Create `lib/mix/tasks/goodwizard.scenario.ex` — argument parsing with `OptionParser` (switches: `--workspace`, `--timeout`, `--no-cleanup`), subcommands `run` and `list`.
- [x] 4.2 Implement temp workspace setup — create directory structure, copy bootstrap files and brain schemas from real workspace. Cleanup in `after` block.
- [x] 4.3 Implement inline query detection — if arg contains spaces or doesn't match a scenario file, wrap as single-query scenario.
- [x] 4.4 Implement structured output formatter — section-delimited output with scenario name, status, per-step results, tool calls, log entries, and assertion results.
- [x] 4.5 Implement `list` subcommand — display available scenarios with names and descriptions.

### 5. Verification

- [x] 5.1 `mix compile --warnings-as-errors` passes with no warnings
- [x] 5.2 `mix goodwizard.scenario list` shows `smoke_test` and `memory_continuity`
- [x] 5.3 `mix goodwizard.scenario run "Hello"` runs inline query and prints structured result
- [x] 5.4 `mix goodwizard.scenario run smoke_test` runs file-based scenario with assertions
