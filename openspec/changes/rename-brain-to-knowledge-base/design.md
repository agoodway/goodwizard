## Context

The codebase currently uses `brain` naming across modules (`Goodwizard.Brain`), workspace directories (`brain/`), schema paths, prompts, CLI/help output, and OpenSpec/docs text. This naming is both internal and user-facing. The proposal and specs require a terminology transition to canonical "knowledge base" with `kb` as a short alias, plus a migration path for existing workspaces and integrations.

Constraints:
- Existing workspaces may already contain `brain/` data and references.
- Current features should continue to work during migration.
- The change spans docs, runtime behavior, and filesystem conventions.

## Goals / Non-Goals

**Goals:**
- Establish canonical naming: "knowledge base" (and `kb` alias).
- Provide compatibility for legacy `brain` references during a migration window.
- Define deterministic migration behavior for workspace layout and references.
- Enable eventual removal of deprecated `brain` interfaces with clear errors.

**Non-Goals:**
- Re-architecting the underlying entity model or storage format.
- Changing business behavior of entity CRUD operations beyond naming/migration semantics.
- Introducing net-new knowledge features unrelated to terminology migration.

## Decisions

1. Canonical naming and alias policy
- Decision: Treat "knowledge base" as canonical in all user-facing surfaces; accept `kb` as shorthand; treat `brain` as legacy-only during migration.
- Rationale: Improves clarity without sacrificing speed for power users.
- Alternative considered: Keep "brain" and only adjust docs. Rejected because it preserves ambiguity and mixed language in APIs.

2. Compatibility layer over immediate hard break
- Decision: Add a compatibility resolver that maps legacy `brain`-named interfaces to knowledge base equivalents and emits deprecation warnings.
- Rationale: Prevents abrupt breakage for existing automations/workspaces.
- Alternative considered: Immediate hard cutover. Rejected due to high migration risk and poor UX.

3. Workspace migration strategy
- Decision: Support both explicit migration and runtime mapping from `brain/` to knowledge-base layout; normalize internal references to canonical names when rewritten.
- Rationale: Allows safe transition for existing data while converging on a single canonical layout.
- Alternative considered: Require manual migration only. Rejected because it is error-prone and likely to leave installations in mixed states.

4. Staged deprecation lifecycle
- Decision: Define phases: (a) compatibility + warnings, (b) warning escalation, (c) removal with actionable error guidance.
- Rationale: Gives users predictable time to update while enabling eventual cleanup.
- Alternative considered: Permanent alias support. Rejected due to indefinite maintenance burden and continued terminology drift.

## Risks / Trade-offs

- [Mixed naming during transition causes confusion] -> Mitigation: central naming policy, consistent warning text, and migration docs/checklist.
- [Migration could miss edge-case references] -> Mitigation: add reference normalization tests and idempotent migration passes.
- [Temporary dual-path support adds complexity] -> Mitigation: isolate mapping logic in one compatibility module and enforce removal timeline.
- [Third-party scripts depend on `brain` paths] -> Mitigation: provide explicit deprecation notices and replacement examples in CLI/help output.

## Migration Plan

1. Introduce canonical naming constants and compatibility mapper for legacy names.
2. Update user-facing text (prompts, docs, CLI help) to canonical terminology.
3. Add workspace migration logic for directory/path/reference normalization.
4. Emit deprecation warnings whenever legacy `brain` interfaces are used.
5. Add tests for canonical behavior, compatibility behavior, and migration idempotency.
6. After migration window, remove deprecated interfaces and return actionable errors.

Rollback strategy:
- Keep compatibility mapper and legacy path resolution behind feature flags/configurable cutover points during rollout.
- If issues occur, re-enable compatibility behavior and rerun migration checks without data deletion.

## Open Questions

- What is the exact migration-window duration before hard removal?
- Should canonical config keys use `knowledge_base` only, or accept both `knowledge_base` and `kb`?
- Should on-disk canonical directory be `knowledge_base/` or `kb/` (with the other only as alias)?
- Do we need a dedicated migration command, or is startup-time migration sufficient?
