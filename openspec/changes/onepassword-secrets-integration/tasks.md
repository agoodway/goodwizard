## 1. Secrets Module

- [ ] 1.1 Create `lib/goodwizard/secrets.ex` with `secret_ref?/1`, `resolve/2`, `resolve_map/2`, `available?/0`, `invalidate/1`, `invalidate_all/0` functions. Include `@op_prefix "op://"`, runner injection via `:runner` option, `--no-newline` flag on `op read`, and URI redaction in log messages.
- [ ] 1.2 Write `test/goodwizard/secrets_test.exs` with mock runner tests covering: secret_ref? detection, successful resolution, failure fallback, timeout/raise handling, whitespace trimming, map walking, empty maps, list values, and available? check.

## 2. Config Integration

- [ ] 2.1 Add `"secrets" => %{"cache_ttl_minutes" => 30}` to `@defaults` in `lib/goodwizard/config.ex`.
- [ ] 2.2 Add `resolve_secrets/2` private function to `config.ex` that calls `Secrets.resolve_map(config, cache: false)` with optional `:secrets_runner` passthrough from opts.
- [ ] 2.3 Add `resolve_app_env_secrets/1` private function to `config.ex` that checks and resolves `op://` values in `Application.get_env(:telegex, :token)`, `System.get_env("ANTHROPIC_API_KEY")`, and `System.get_env("OPENAI_API_KEY")`, updating both `System.put_env` and `Application.put_env`.
- [ ] 2.4 Wire `resolve_secrets/2` and `resolve_app_env_secrets/1` into `Config.init/1` pipeline after `apply_env_overrides` and before `validate_numeric_ranges`.
- [ ] 2.5 Write `test/goodwizard/config_secrets_test.exs` with integration tests: TOML op:// resolution, env var op:// resolution, and graceful fallback on op CLI failure.

## 3. Config Files

- [ ] 3.1 Add commented `[secrets]` section to `config.toml` with `cache_ttl_minutes` option.
- [ ] 3.2 Add commented `[secrets]` section to `@default_config` in `lib/mix/tasks/goodwizard.setup.ex`.
