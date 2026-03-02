## 1. Canonical Naming and Interface Mapping

- [x] 1.1 Define canonical terminology constants (`knowledge base`, `knowledge_base`, `kb`) and legacy aliases (`brain`) in a shared module.
- [x] 1.2 Inventory current `brain`-named user-facing interfaces (actions, CLI/help text, prompts, config keys) and map each to a canonical replacement.
- [x] 1.3 Implement compatibility resolution so legacy `brain` interface names route to canonical behavior.
- [x] 1.4 Add standardized deprecation warning messages for all legacy interface entry points.

## 2. Workspace and Schema Migration

- [x] 2.1 Implement workspace path migration/mapping from `brain/` to canonical knowledge-base layout.
- [x] 2.2 Migrate or normalize schema discovery references that currently depend on `brain`-named paths.
- [x] 2.3 Ensure migration is idempotent and safe for partially migrated workspaces.
- [x] 2.4 Add rollback-safe handling so migration failures do not delete or corrupt existing data.

## 3. User-Facing Language Updates

- [x] 3.1 Update prompts, preambles, and runtime guidance text to use canonical "knowledge base" wording.
- [x] 3.2 Update CLI command descriptions/help output to prefer canonical names and show `kb` alias.
- [x] 3.3 Update OpenSpec/docs references in scope to canonical terminology where behavior is described.

## 4. Deprecation Lifecycle and Removal Readiness

- [x] 4.1 Add migration-window configuration and enforcement points for legacy-name support.
- [x] 4.2 Implement post-window errors for removed `brain` interfaces with actionable replacement guidance.
- [x] 4.3 Add telemetry/logging hooks for legacy usage to support cutover decisions.

## 5. Verification and Regression Coverage

- [x] 5.1 Add tests that assert canonical terminology appears in user-facing outputs.
- [x] 5.2 Add tests that legacy `brain` interfaces continue to work during migration and emit deprecation warnings.
- [x] 5.3 Add tests covering workspace/schema migration behavior, including idempotent reruns.
- [x] 5.4 Add tests that removed legacy interfaces fail with clear replacement guidance after cutoff.
- [x] 5.5 Run `mix check` and fix any resulting failures before implementation handoff.
