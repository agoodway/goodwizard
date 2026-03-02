## Why

The product and codebase currently use the term "brain" for structured long-term knowledge, which is unclear and inconsistent with user-facing language. Renaming this concept to "knowledge base" (short alias: "kb") improves clarity across docs, commands, prompts, and APIs before additional capabilities build on this area.

## What Changes

- Replace user-facing and internal terminology from "brain" to "knowledge base" across specs, docs, prompts, actions, and CLI/help text.
- Introduce a canonical "knowledge base" naming model with `kb` as an accepted short alias where appropriate.
- Update workspace paths, configuration keys, and schema/discovery references that currently use `brain` naming.
- Define migration/compatibility behavior for existing workspaces and integrations.
- Use a staged legacy policy:
  - During the migration window, legacy `brain` interfaces continue to resolve to canonical behavior with deprecation warnings.
  - After the migration window closes, deprecated `brain` interfaces are rejected with actionable replacement guidance to `knowledge_base`/`kb`.

## Capabilities

### New Capabilities
- `knowledge-base-terminology-migration`: Define and enforce the rename from `brain` to `knowledge base`/`kb`, including canonical terms, compatibility rules, and migration behavior.

### Modified Capabilities
- None.

## Impact

- Affected code: modules/actions/plugins that currently use `Brain` naming, workspace bootstrap/setup code, schema loading, and prompt/context builders.
- Affected interfaces: CLI command/help output, configuration keys, tool/action names, and user-facing docs.
- Affected data/layout: workspace directory and reference conventions currently rooted at `brain/`.
- Dependencies/systems: OpenSpec change artifacts and tests that reference existing `brain` terminology.
