## 1. SUBAGENT.md Parser

- [ ] 1.1 Create `lib/goodwizard/plugins/specializedagents/parser.ex` — reuse frontmatter parsing from `PromptSkills.Parser` (YAML frontmatter + markdown body split)
- [ ] 1.2 Define parsed config struct: `%{name, description, model, max_iterations, timeout, tools, path, dir, content, resources}`
- [ ] 1.3 Validate required fields (`name`, `description`) and apply defaults for optional fields (`model` defaults to `anthropic:claude-sonnet-4-5`, `max_iterations` to 10, `timeout` to 120_000, `tools` to `[:filesystem, :shell, :brain]`)

## 2. Subagents Plugin

- [ ] 2.1 Create `lib/goodwizard/plugins/specializedagents.ex` using `Jido.Plugin` with `state_key: :specializedagents`
- [ ] 2.2 Implement `mount/2` — scan `workspace/specializedagents/` for subdirectories containing `SUBAGENT.md`, parse each, return `%{agents: %{name => config}}`
- [ ] 2.3 Add cache integration — store parsed configs under `"specializedagents:list"` key with 5-minute TTL
- [ ] 2.4 Index resource files (non-SUBAGENT.md files in each agent directory) in the config map

## 3. Default Subagent Configs

- [ ] 3.1 Create `priv/workspace/specializedagents/researcher/SUBAGENT.md` — research-focused agent with filesystem, shell, and brain tools; system prompt emphasizing investigation, source gathering, and structured findings
- [ ] 3.2 Create `priv/workspace/specializedagents/coder/SUBAGENT.md` — implementation-focused agent with filesystem, shell, and brain tools; system prompt emphasizing code quality, testing, and minimal changes

## 4. Setup Task

- [ ] 4.1 Add `"specializedagents"` to `@subdirs` in `Mix.Tasks.Goodwizard.Setup` so `mix goodwizard.setup` creates `workspace/specializedagents/`
- [ ] 4.2 Add a `setup_specializedagents/1` function that creates each default role subdirectory (`researcher/`, `coder/`) and seeds its `SUBAGENT.md` using the existing `seed_file` pattern (skip if exists)
- [ ] 4.3 Call `setup_specializedagents/1` from `run/1` after `setup_bootstrap_files`

## 5. Agent Registration

- [ ] 5.1 Add `Goodwizard.Plugins.Subagents` to the plugins list in `Goodwizard.Agent`

## 6. Tests

- [ ] 6.1 Test: parser extracts frontmatter and body from valid SUBAGENT.md
- [ ] 6.2 Test: parser applies defaults for missing optional fields
- [ ] 6.3 Test: parser returns error for missing required fields (name, description)
- [ ] 6.4 Test: plugin scans directory and builds agents map keyed by name
- [ ] 6.5 Test: plugin handles empty specializedagents directory gracefully
- [ ] 6.6 Test: setup task creates `specializedagents/` directory and seeds default role configs
