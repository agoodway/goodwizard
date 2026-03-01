## 1. Backend Behaviour and Dispatcher

- [ ] 1.1 Create `Goodwizard.Logging.Backend` behaviour module with `@callback init(map()) :: {:ok, term()} | {:error, term()}` and `@callback log(term(), :logger.log_event()) :: :ok`
- [ ] 1.2 Create `Goodwizard.Logging.Dispatcher` module that implements an Erlang `:logger` handler — stores backend states, fans out events to all backends, catches per-backend errors
- [ ] 1.3 Add `Goodwizard.Logging.Dispatcher.agent_visible_backends/0` helper that returns states of backends with `agent_visible: true`
- [ ] 1.4 Add per-backend failure warning throttling in Dispatcher (warn once per failing backend until recovery)

## 2. Built-in Backends

- [ ] 2.1 Create `Goodwizard.Logging.Backends.File` implementing the behaviour — `init/1` creates the directory and initializes backend state; `log/2` appends formatted events to `<dir>/<env>.log`
- [ ] 2.2 Create `Goodwizard.Logging.Backends.Webhook` implementing the behaviour — `init/1` validates URL config and returns it as state; `log/2` formats the event as JSON and HTTP POSTs via `Req` (fire-and-forget, async)
- [ ] 2.3 Implement custom backend resolution (`type = "custom"`) with module validation and callback checks; skip invalid entries with warning

## 3. Config System

- [ ] 3.1 Add `"logging" => %{"dir" => "logs", "backends" => []}` to `@defaults` in `lib/goodwizard/config.ex`
- [ ] 3.2 Add `{"GOODWIZARD_LOG_DIR", ["logging", "dir"]}` to `@env_overrides` in `lib/goodwizard/config.ex`
- [ ] 3.3 Add `log_dir/0` accessor to `Goodwizard.Config` — returns expanded path of the first agent-visible file backend's directory, or `nil` when none exists
- [ ] 3.4 Add `log_backends/0` accessor to `Goodwizard.Config` — returns the resolved list of backend configs, normalizing the simple `dir`-only form into a single-element backends list
- [ ] 3.5 Add `Goodwizard.Logging.ConfigResolver` shared module for backend resolution (defaults + TOML + env override) used by both startup and runtime config accessors

## 4. Application Startup

- [ ] 4.1 Replace `maybe_add_file_logger/0` in `Goodwizard.Application` with `start_log_backends/0` that resolves backend configs via `Goodwizard.Logging.ConfigResolver`, initializes each backend, and registers the Dispatcher as a single `:logger` handler
- [ ] 4.2 Ensure `GOODWIZARD_LOG_DIR` override behavior is explicit: override first file backend dir when present; warn and ignore when no file backend exists

## 5. Config Templates

- [ ] 5.1 Add commented `[logging]` section to `config.toml` showing both simple `dir` form and multi-backend examples
- [ ] 5.2 Add commented `[logging]` section to `@default_config` in `lib/mix/tasks/goodwizard.setup.ex`

## 6. Dev-Log Skill

- [ ] 6.1 Update `.claude/skills/dev-log/SKILL.md` to reference `Goodwizard.Config.log_dir/0` (agent-visible path) instead of hardcoded `logs/`
- [ ] 6.2 Handle `Goodwizard.Config.log_dir/0 == nil` in dev-log workflow with a clear user-facing message

## 7. Tests

- [ ] 7.1 Test `Goodwizard.Logging.Backends.File` — init creates directory and `log/2` appends correctly to `<dir>/<env>.log`
- [ ] 7.2 Test `Goodwizard.Logging.Backends.Webhook` — init validates URL, log/2 formats and posts (mock HTTP)
- [ ] 7.3 Test `Goodwizard.Logging.Dispatcher` — fan-out to multiple backends, error isolation (one backend crash doesn't affect others), agent_visible filtering, and warning throttling
- [ ] 7.4 Test `Config.log_dir/0` returns correct path for simple config, multi-backend config, and env var override; returns `nil` when no agent-visible file backend exists
- [ ] 7.5 Test `Config.log_backends/0` normalizes simple dir-only config into backends list
- [ ] 7.6 Test custom backend resolution — valid custom module initializes; invalid module is skipped with warning
- [ ] 7.7 Test `GOODWIZARD_LOG_DIR` with backends but no file entry — override ignored with warning

## 8. Verification

- [ ] 8.1 Run `mix compile` with zero warnings
- [ ] 8.2 Run `mix test` with all tests passing
- [ ] 8.3 Verify default behavior: app writes to `logs/dev.log` with no config changes
