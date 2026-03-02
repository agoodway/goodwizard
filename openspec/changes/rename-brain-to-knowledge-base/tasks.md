## 1. Canonical Naming and Interface Mapping

> Tracking rule: check a task only when its mapped `td` story is `closed`.

- [ ] 1.1 Define canonical terminology constants (`knowledge base`, `knowledge_base`, `kb`) and legacy aliases (`brain`) in a shared module.
- [ ] 1.2 Inventory current `brain`-named user-facing interfaces (actions, CLI/help text, prompts, config keys) and map each to a canonical replacement.
- [ ] 1.3 Implement compatibility resolution so legacy `brain` interface names route to canonical behavior.
- [ ] 1.4 Add standardized deprecation warning messages for all legacy interface entry points.

## 2. Workspace and Schema Migration

- [ ] 2.1 Implement workspace path migration/mapping from `brain/` to canonical knowledge-base layout.
- [ ] 2.2 Migrate or normalize schema discovery references that currently depend on `brain`-named paths.
- [ ] 2.3 Ensure migration is idempotent and safe for partially migrated workspaces.
- [ ] 2.4 Add rollback-safe handling so migration failures do not delete or corrupt existing data.

## 3. User-Facing Language Updates

- [ ] 3.1 Update prompts, preambles, and runtime guidance text to use canonical "knowledge base" wording.
- [ ] 3.2 Update CLI command descriptions/help output to prefer canonical names and show `kb` alias.
- [ ] 3.3 Update OpenSpec/docs references in scope to canonical terminology where behavior is described.

## 4. Deprecation Lifecycle and Removal Readiness

- [ ] 4.1 Add migration-window configuration and enforcement points for legacy-name support.
- [ ] 4.2 Implement post-window errors for removed `brain` interfaces with actionable replacement guidance.
- [ ] 4.3 Add telemetry/logging hooks for legacy usage to support cutover decisions.

## 5. Verification and Regression Coverage

- [ ] 5.1 Add tests that assert canonical terminology appears in user-facing outputs.
- [ ] 5.2 Add tests that legacy `brain` interfaces continue to work during migration and emit deprecation warnings.
- [ ] 5.3 Add tests covering workspace/schema migration behavior, including idempotent reruns.
- [ ] 5.4 Add tests that removed legacy interfaces fail with clear replacement guidance after cutoff.
- [ ] 5.5 Run `mix check` and fix any resulting failures before implementation handoff.
