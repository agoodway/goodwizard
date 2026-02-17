---
name: refresh-workspace
description: >-
  Detect and fix drift between workspace files and source templates. Use when the user says
  "refresh workspace", "check workspace", "workspace drift", "update workspace files",
  "sync workspace", "workspace health", or wants to see if their workspace is up to date
  with current templates.
---

# Refresh Workspace

Detect drift between the on-disk workspace and the canonical templates defined in source code, then interactively fix any gaps.

## Commands

- **`/refresh-workspace`** — Full interactive refresh (report + fix)
- **`/refresh-workspace --dry-run`** — Report only, no filesystem changes
- **`/refresh-workspace --category <name>`** — Limit to one category: `dirs`, `files`, `schemas`, or `config`

## Source Files (read on every run)

| Source | What to extract |
|--------|-----------------|
| `lib/mix/tasks/goodwizard.setup.ex` | `@default_identity_md`, `@default_soul_md`, `@default_user_md`, `@default_tools_md`, `@default_agents_md`, `@default_heartbeat_md` heredocs; `@default_config` heredoc; `@subdirs` list; `@bootstrap_files` list |
| `lib/goodwizard/brain/seeds.ex` | `@entity_types` list; `build_schema` version arg per type (default 1, people=2, companies=2) |

## Tool policy

**Scanning (Steps 0–3)**: Use **Read**, **Glob**, and **Grep** exclusively. These are auto-approved read-only tools that never trigger confirmation prompts. No Bash during scanning.

**Writing (Step 4)**: Use **Bash** to batch all writes into minimal commands. This gives the user one approval per batch instead of per-file prompts from Write/Edit.

Specific write patterns:
- **Create directories**: `mkdir -p dir1 dir2 ...` (all missing dirs in one command)
- **Create/overwrite files**: `cat <<'EOF' > path` heredoc
- **Append to files**: `cat <<'EOF' >> path` heredoc
- **Regenerate schemas**: `mix run -e '...'`

## Workflow

### Step 0 — Resolve workspace path

1. Read `config.toml` with the Read tool.
2. Extract `[agent] workspace` value. Default to `priv/workspace/` if not set.
3. Verify the workspace directory exists with `Glob` (e.g. glob for `<workspace>/*`). If nothing matches, tell the user to run `mix goodwizard.setup` first and stop.

### Step 1 — Extract templates

Read both source files listed above using the Read tool. Extract:

- **Bootstrap file templates**: The 6 `@default_*_md` module attributes from `goodwizard.setup.ex`. These are the heredoc strings assigned to each attribute.
- **Subdirectory list**: The `@subdirs` list (`memory`, `sessions`, `skills`).
- **Entity types**: The `@entity_types` list from `seeds.ex` (`people`, `places`, `events`, `notes`, `tasks`, `companies`, `tasklists`, `webpages`).
- **Schema versions**: The version argument passed to `build_schema` for each type. Most types use the default of `1`; `people` and `companies` explicitly pass `2`.
- **Config template**: The `@default_config` heredoc.

If either source file cannot be read or parsed, report the failure loudly and stop — do not silently skip.

### Step 2 — Scan & classify

Use **only** Read, Glob, and Grep tools here. No Bash. All are auto-approved and produce zero confirmation prompts.

**Directory check** — Use Glob to list what exists, then compare against the expected set:
- Run `Glob` with pattern `<workspace>/*/` and `<workspace>/*/*/` to discover existing directories.
- Compare results against the expected list: `memory/`, `sessions/`, `skills/`, `brain/schemas/`, `brain/<type>/` (for each entity type), `scheduling/cron/`.
- Any expected directory not in the glob results is **Missing**; the rest are **Current**.

**Bootstrap file check** — Use Glob + Read:
- Run `Glob` with pattern `<workspace>/*.md` to find which bootstrap files exist.
- Any of the 6 expected files not found by glob is **Missing**.
- For files that exist, use `Read` to get their content and compare to the template string extracted in Step 1:
  - Content matches template exactly → **Current**
  - Content differs → **Changed** (append `[customizable]` for IDENTITY.md, SOUL.md, USER.md)
- Read all existing bootstrap files in parallel to minimize round trips.

**Schema version check** — Use Glob + Read:
- Run `Glob` with pattern `<workspace>/brain/schemas/*.json` to find existing schemas.
- For each expected type, if `<type>.json` is not in results → **Missing**.
- For each that exists, `Read` the file and extract the `"version"` field from the JSON:
  - Disk version == source version → **Current**
  - Disk version < source version → **Outdated** (show `disk → source`)
  - Disk version > source version → **Ahead** (informational)
- Any `.json` files found that are NOT in `@entity_types` → **Custom** (informational).
- Read all existing schema files in parallel.

**Config section check** — The config.toml was already read in Step 0. Compare its sections and keys against the `@default_config` template using string matching:
- For each section header (`[section]`) in the template, check if it appears in the disk config.
- For each key in the template (ignoring commented-out lines starting with `#`), check if that key appears under the same section in the disk config.
- Present in disk → **Current**; absent → **New**.

#### Classification reference

| Category | Items | Statuses |
|----------|-------|----------|
| **Directories** | memory/, sessions/, skills/, brain/schemas/, brain/\<type\>/, scheduling/cron/ | Missing, Current |
| **Bootstrap files** | IDENTITY.md, SOUL.md, USER.md, TOOLS.md, AGENTS.md, HEARTBEAT.md | Missing, Changed, Changed [customizable], Current |
| **Brain schemas** | \<type\>.json for each entity type | Missing, Outdated, Current, Ahead, Custom |
| **Config** | Sections/keys in template vs config.toml | New, Current |

Customizable files: IDENTITY.md, SOUL.md, USER.md. If changed, append `[customizable]` to status.

### Step 3 — Display report

Present the results as markdown tables, one per category:

```
## Workspace Refresh Report

### Directories
| Directory | Status |
|-----------|--------|
| memory/ | Current |
| brain/widgets/ | Missing |

### Bootstrap Files
| File | Status |
|------|--------|
| IDENTITY.md | Changed [customizable] |
| HEARTBEAT.md | Missing |
| TOOLS.md | Current |

### Brain Schemas
| Schema | Disk Version | Source Version | Status |
|--------|-------------|----------------|--------|
| people.json | 2 | 2 | Current |
| tasks.json | — | 1 | Missing |

### Config (config.toml)
| Section / Key | Status |
|---------------|--------|
| [scheduling] | Current |
| [session] max_cli_sessions | New |

### Summary
- Directories: 12 current, 1 missing
- Files: 4 current, 1 changed, 1 missing
- Schemas: 7 current, 1 missing
- Config: 10 current, 2 new
```

If `--dry-run` was specified, print the report and **stop here**. Do not proceed to Step 4.

If `--category` was specified, only show the relevant category table plus summary line.

### Step 4 — Remediate interactively

Present findings from Step 3, then ask the user what to fix. Use **AskUserQuestion** to collect choices, then execute all approved writes via **Bash** — batching into as few commands as possible.

#### Directories (missing)

Batch-create all missing directories in one `mkdir -p` command:
```bash
mkdir -p "<workspace>/brain/webpages" "<workspace>/scheduling/cron"
```

#### Bootstrap files

- **Missing files**: Show the template content inline in your message. Ask whether to create. If approved, write via Bash heredoc:
  ```bash
  cat <<'EOF' > "<workspace>/HEARTBEAT.md"
  <template content here>
  EOF
  ```
- **Changed files (not customizable)**: You already have both the disk content and the template from Step 2 reads. Show a unified diff inline in your message (format it yourself as a markdown code block — do NOT use Bash `diff`). Ask per-file: **skip** or **overwrite**. If overwrite approved, write via Bash heredoc.
- **Changed files (customizable — IDENTITY, SOUL, USER)**: Default recommendation is **skip**. Explain that this file is meant to be customized and the diff is expected. Still offer overwrite if the user explicitly wants to reset to the template.
- Batch multiple approved file writes into a single Bash command when possible (chain with `&&`).

#### Brain schemas

- **Missing schemas**: Regenerate via mix:
  ```bash
  mix run -e 'Goodwizard.Brain.Schema.save("<workspace>", "<type>", Goodwizard.Brain.Seeds.schema_for("<type>"))'
  ```
- **Outdated schemas** (disk version < source version): Show the version difference. Warn that updating the schema does NOT migrate existing entity data — the user should verify compatibility. Ask whether to update or skip. If approved, regenerate via the same `mix run -e` command.
- **Ahead** and **Custom**: Informational only. No action offered.
- Batch multiple schema regenerations into a single `mix run -e` command when possible.

#### Config additions

- **New sections/keys**: Show the relevant lines from the `@default_config` template inline. Ask the user whether to append. If approved, append via Bash heredoc:
  ```bash
  cat <<'EOF' >> config.toml

  [session]
  # Maximum number of CLI session files to retain. Oldest files are
  # deleted when the limit is exceeded. Only affects cli-direct-* files.
  # max_cli_sessions = 50
  EOF
  ```

### Step 5 — Summary

After all remediation, print a final tally:

```
## Refresh Complete
- Directories created: 1
- Files created: 1
- Files updated: 0
- Schemas regenerated: 0
- Config options added: 2
- Items skipped: 3
```

## Guardrails

- **Never silently overwrite** — always show a diff and ask before changing any existing file
- **Customizable files** (IDENTITY, SOUL, USER) get extra protection: default action is "skip" with an explanation that customization is expected
- **Schema updates** always warn about existing entity data compatibility
- **Config changes** are additive only — new sections/keys, never value changes to existing keys
- **Custom/extra schemas** are reported as informational, never removed or modified
- **Extraction failures** are reported loudly, not silently skipped — the skill stops if source files can't be parsed
- **No destructive operations** — this skill never deletes files or directories
- **`--dry-run`** means absolutely no filesystem writes — report only
