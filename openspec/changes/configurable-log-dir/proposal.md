## Why

The log file directory is hardcoded to `<cwd>/logs/` in `application.ex`. Users cannot redirect logs to a different location via `config.toml` or environment variables. This makes it impossible to place logs on a separate volume, use a shared log directory across instances, or customize the path for deployment environments.

Additionally, there is no way to send logs to multiple destinations simultaneously. A common need is writing logs to a local file the agent can read (for the dev-log skill and self-debugging) while also shipping logs to an external location the agent cannot access (for audit trails, compliance, or centralized logging services). The current single-file approach forces a choice between agent accessibility and operational logging.

## What Changes

- Add a `[logging]` section to the config system with a `backends` list (default: one file backend writing to `"logs"`)
- Add `GOODWIZARD_LOG_DIR` environment variable override for the primary file backend
- Add `Config.log_dir/0` convenience accessor (returns the first agent-visible file backend's directory, or `nil` when none exists)
- Introduce a `Goodwizard.Logging.Backend` behaviour with `init/1` and `log/2` callbacks
- Ship two built-in backends: `Goodwizard.Logging.Backends.File` and `Goodwizard.Logging.Backends.Webhook` (HTTP via `Req`)
- Each backend config includes an `agent_visible` flag — only `agent_visible: true` backends are exposed to agent actions (dev-log skill, self-debugging tools)
- Update `application.ex` to start all configured backends at boot
- Add `[logging]` section to `config.toml` and the setup task's default config template
- Update the dev-log skill to query only agent-visible log paths

## Capabilities

### New Capabilities

- `configurable-log-dir`: Configurable log file storage directory via TOML config and environment variable
- `multi-destination-logging`: Route logs to multiple backends simultaneously via a configured backends list
- `log-backend-behaviour`: Adapter pattern (`Goodwizard.Logging.Backend` behaviour) allowing custom log destinations (file, webhook, or user-defined)
- `agent-visible-logs`: Per-backend `agent_visible` flag controlling which log sources the agent can read

### Modified Capabilities

None — no existing specs are affected.

## Impact

- **Config system** (`lib/goodwizard/config.ex`): new defaults entry, env override, accessor function
- **Application startup** (`lib/goodwizard/application.ex`): log dir resolution + multi-backend init
- **New modules**: `Goodwizard.Logging.Backend` (behaviour), `Goodwizard.Logging.Backends.File`, `Goodwizard.Logging.Backends.Webhook`, `Goodwizard.Logging.Dispatcher` (single logger handler fan-out), `Goodwizard.Logging.ConfigResolver` (shared runtime config resolution)
- **Config templates** (`config.toml`, `lib/mix/tasks/goodwizard.setup.ex`): new `[logging]` section with backends list
- **Dev-log skill** (`.claude/skills/dev-log/SKILL.md`): updated to query agent-visible backends only
- **No breaking changes** — default behavior (`logs/<env>.log`, single file backend, agent-visible) is preserved when no `[logging]` section is configured
