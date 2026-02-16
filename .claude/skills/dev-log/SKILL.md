---
name: dev-log
description: >-
  Read and search the Elixir dev log (log/dev.log) for debugging. Use when the user says
  "check the logs", "dev log", "what's in the log", "look at logs", "any errors in logs",
  "check dev.log", or when debugging an issue and log context would help. Also use when
  the user references @log/dev.log.
---

# Dev Log Reader

Read `log/dev.log` relative to the project root to find relevant log entries for debugging.

## Commands

- **`/dev-log`** — Show recent errors and warnings (default)
- **`/dev-log <search-term>`** — Search for specific term in logs
- **`/dev-log errors`** — Show only error-level entries
- **`/dev-log tail`** — Show the last 100 lines
- **`/dev-log clear`** — Delete the log file

## Workflow

1. Determine what the user needs:
   - No args or "errors": filter for `[error]` and `[warning]` entries
   - A search term: grep for that term
   - "tail": show recent entries
   - "all": show errors, warnings, and notices
   - "clear": delete `log/dev.log` using `rm log/dev.log` via Bash, then confirm deletion

2. Read the log file using the appropriate approach:
   - Use `Grep` tool with pattern matching against `log/dev.log`
   - For tail: use `Read` tool with offset on `log/dev.log`
   - Strip ANSI color codes mentally when analyzing — log lines are wrapped in `\e[31m` (red/error), `\e[33m` (yellow/warning), `\e[36m` (cyan/debug), `\e[22m` (dim/info+notice)

3. Present findings concisely:
   - Group by log level
   - Show timestamps
   - For errors: include surrounding context (2-3 lines before/after) using Grep `-C` parameter
   - Highlight actionable items (exceptions, crashes, failed tool executions)
   - If the log is large (>5000 lines), focus on the most recent entries

## Log Format

Standard Elixir Logger output:
```
HH:MM:SS.mmm [level] message
```

Levels in order of severity: `debug`, `info`, `notice`, `warning`, `error`

Key patterns to watch for:
- `[error] Tool execution exception` — action/tool failure
- `[error]` with stacktraces — application crashes
- `** (EXIT)` or `** (throw)` — OTP process failures
- `[warning]` — degraded behavior
- `status=error` — failed action executions with duration info
