# Phase 1: Scaffold and Config — Tasks

## Backend

- [x] 1.1 Create Mix project with mix.exs (deps: jido, jido_ai, toml, jason)
- [x] 1.2 Create config/config.exs and config/runtime.exs with base application config
- [x] 1.3 Create Goodwizard top-level module (lib/goodwizard.ex)
- [x] 1.4 Create Goodwizard.Application supervision tree starting Config + Jido
- [x] 1.5 Create Goodwizard.Jido instance module (use Jido, otp_app: :goodwizard)
- [x] 1.6 Create Goodwizard.Config GenServer — TOML loading, env var overrides, deep merge, workspace creation
- [x] 1.7 Implement Config API: get/0, get/1, workspace/0, model/0
- [x] 1.8 Add `jido_character ~> 1.0` to mix.exs deps
- [x] 1.9 Parse optional `[character]` TOML config section (name, tone, style, traits) — Config.get(:character) returns map or nil

## Test

- [x] 2.1 Create test_helper.exs
- [x] 2.2 Test Config loads from a temp TOML file
- [x] 2.3 Test env vars override TOML values
- [x] 2.4 Test missing TOML file uses defaults
- [x] 2.5 Test workspace/0 expands ~ to full path
- [x] 2.6 Test Config.get(:character) returns parsed map when present, nil when absent
