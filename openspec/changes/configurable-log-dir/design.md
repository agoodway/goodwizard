## Context

Log files are written to `<cwd>/logs/<env>.log` via Erlang's `:logger_std_h` handler, configured in `Goodwizard.Application.maybe_add_file_logger/0`. The path is hardcoded — there is no config knob to change it, and there is no way to send logs to more than one destination.

The config system (`Goodwizard.Config`) uses a three-layer merge: hardcoded `@defaults` → `config.toml` → env vars. Other paths (workspace, memory, sessions) already follow this pattern with convenience accessors and env var overrides.

## Goals / Non-Goals

**Goals:**

- Allow users to set a custom log directory via `config.toml` (`[logging] dir`) or `GOODWIZARD_LOG_DIR` env var
- Support multiple log destinations via a `[[logging.backends]]` list in TOML
- Provide a `Goodwizard.Logging.Backend` behaviour so users can write custom backends (e.g. ship logs to Datadog, S3, syslog)
- Ship two built-in backends: `File` (local filesystem) and `Webhook` (HTTP POST via `Req`)
- Let each backend declare `agent_visible` so the agent can only read logs it's meant to see
- Preserve the default behavior (`logs/<env>.log`, single file) when unconfigured
- Expose `Config.log_dir/0` for runtime use by other modules (e.g. the dev-log skill)

**Non-Goals:**

- Configuring the log file *name* (stays `<env>.log` for file backends)
- Configuring log level, format, or rotation via this change
- Implementing a full log aggregation pipeline — the webhook backend is fire-and-forget

## Decisions

### 1. Backend behaviour with `init/1` and `log/2`

```elixir
defmodule Goodwizard.Logging.Backend do
  @type config :: map()
  @type state :: term()

  @callback init(config()) :: {:ok, state()} | {:error, term()}
  @callback log(state(), :logger.log_event()) :: :ok
end
```

`init/1` receives the backend's config map from TOML. `log/2` receives the state returned by `init` plus an Erlang logger event. Backends are responsible for their own buffering/batching.

**Alternative considered:** Using Elixir's `Logger.Backend` behaviour. Rejected because it requires compile-time config in `config/config.exs` and doesn't support runtime TOML-driven config easily. Erlang's `:logger` handler system is more flexible and already used by the app.

### 2. Dispatcher as a single `:logger` handler

Rather than adding one Erlang logger handler per backend, a single `Goodwizard.Logging.Dispatcher` module registers as one `:logger` handler and fans out to all configured backends. This keeps the Erlang handler table simple and gives us control over error isolation (one backend crashing doesn't take down others).

### 3. Shared resolver for startup and runtime callers

`maybe_add_file_logger/0` runs before the supervision tree starts (line 22), so `Config` GenServer is not alive yet. To avoid config drift, backend resolution is moved into a shared module (`Goodwizard.Logging.ConfigResolver`) that reads defaults + TOML + env overrides without requiring the GenServer.

For the simple case (no `[[logging.backends]]` in TOML), the env var or TOML `dir` key produces a single file backend. When `[[logging.backends]]` is present, each entry is initialized.

`Goodwizard.Application` and `Goodwizard.Config.log_backends/0` both call `Goodwizard.Logging.ConfigResolver.resolve_backends/1` so startup and runtime see identical backend resolution.

`Config.log_dir/0` returns the expanded absolute path of the first agent-visible file backend, or `nil` when no such backend exists.

**Alternative considered:** Moving logger init to a post-Config startup task. Rejected because it would delay file logging and miss early startup messages.

### 4. Custom backend loading and validation

Custom backends use:

```toml
[[logging.backends]]
type = "custom"
module = "MyApp.SyslogBackend"
agent_visible = false
```

Resolution validates that `module` is present, atom-safe (`Module.safe_concat/1`), loaded, and exports the required callbacks from `Goodwizard.Logging.Backend`. Invalid custom backend entries are skipped with a startup warning; healthy backends continue initializing.

### 5. Config structure

Simple case (backward-compatible):

```toml
[logging]
dir = "/var/log/goodwizard"
```

Multi-backend case:

```toml
[[logging.backends]]
type = "file"
dir = "/var/log/goodwizard"
agent_visible = true

[[logging.backends]]
type = "file"
dir = "/mnt/audit/goodwizard"
agent_visible = false

[[logging.backends]]
type = "webhook"
url = "https://logs.example.com/ingest"
agent_visible = false
```

When `[[logging.backends]]` is present, `dir` at the `[logging]` level is ignored. The `GOODWIZARD_LOG_DIR` env var overrides the `dir` of the **first** file-type backend.

### 6. `agent_visible` flag

Each backend config has an `agent_visible` boolean (default: `true` for file, `false` for webhook). The dev-log skill and any future agent self-debugging tools only query backends marked `agent_visible: true`.

`Config.log_dir/0` returns the directory of the first agent-visible file backend. If none exists, it returns `nil`.

### 7. Default value: `"logs"` (relative to cwd)

When no `[logging]` section exists, the system behaves exactly as before: a single file backend writing to `<cwd>/logs/<env>.log`, agent-visible. Relative paths are expanded with `Path.expand/1`. Absolute paths pass through unchanged.

## Risks / Trade-offs

- **No-file backend setups** — If users configure only webhook/custom backends or all file backends as `agent_visible: false`, `Config.log_dir/0` returns `nil` and agent log-reading features must handle that gracefully.
- **Webhook reliability** — The webhook backend is fire-and-forget. If the endpoint is down, logs are lost for that backend. This is acceptable by design.
- **Backend crash isolation** — If a custom backend raises in `log/2`, the Dispatcher catches and logs the error (to other backends) but continues. This means a buggy backend degrades silently rather than loudly. We log a warning on first failure per backend.
- **Warning amplification** — Logging backend failures as warnings can recurse/noise at high volume. Dispatcher must throttle to first-failure-per-backend until recovery.
- **No log rotation** — out of scope, but users pointing logs at a custom dir may expect it. Can be added later under `[logging]`.
- **TOML array-of-tables** — `[[logging.backends]]` is valid TOML but less common. Users unfamiliar with the syntax may need documentation. The simple `dir` form remains for single-destination use.
