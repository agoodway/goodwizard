# Phase 1: Scaffold and Config — Tasks

## Backend

- [ ] 1.1 Create Mix project with mix.exs (deps: jido, jido_ai, toml, jason)
- [ ] 1.2 Create config/config.exs and config/runtime.exs with base application config
- [ ] 1.3 Create Goodwizard top-level module (lib/goodwizard.ex)
- [ ] 1.4 Create Goodwizard.Application supervision tree starting Config + Jido
- [ ] 1.5 Create Goodwizard.Jido instance module (use Jido, otp_app: :goodwizard)
- [ ] 1.6 Create Goodwizard.Config GenServer — TOML loading, env var overrides, deep merge, workspace creation
- [ ] 1.7 Implement Config API: get/0, get/1, workspace/0, model/0
- [ ] 1.8 Add `jido_character ~> 1.0` to mix.exs deps
- [ ] 1.9 Parse optional `[character]` TOML config section (name, tone, style, traits) — Config.get(:character) returns map or nil

## Test

- [ ] 2.1 Create test_helper.exs
- [ ] 2.2 Test Config loads from a temp TOML file
- [ ] 2.3 Test env vars override TOML values
- [ ] 2.4 Test missing TOML file uses defaults
- [ ] 2.5 Test workspace/0 expands ~ to full path
- [ ] 2.6 Test Config.get(:character) returns parsed map when present, nil when absent
