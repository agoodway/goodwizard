## Why

Goodwizard's three-memory architecture (described in `docs/memory-system-plan.md`) requires episodic and procedural memory files to share a common file format: markdown with YAML frontmatter. The existing `Brain.Entity` module handles this for brain entities but is coupled to JSON Schema validation and brain-specific conventions. Episodic and procedural memories need a lighter-weight parser/serializer with no schema validation — entries are flexible by design, with required fields enforced at the action level rather than the parse layer.

Additionally, the existing `Memory.Paths` module only knows about `MEMORY.md` and `HISTORY.md`. The new memory types need path helpers for `memory/episodic/` and `memory/procedural/` subdirectories and individual entry files within them.

This is **proposal 1 of 9** in the memory system series. It provides the shared foundation that proposals 2 (episodic store) and 3 (procedural store) both depend on.

## What Changes

- Create `Goodwizard.Memory.Entry` module — a shared markdown+YAML parser/serializer for memory entries, similar to `Brain.Entity` but without JSON Schema validation
- Update `Goodwizard.Memory.Paths` with path helpers for `episodic/` and `procedural/` subdirectories and individual entry files
- Add a subdirectory validation helper to `Memory.Paths` for safe path construction

## Capabilities

### New Capabilities

- `memory-entry-parser`: Parse and serialize memory entry files using markdown with YAML frontmatter — structured metadata in frontmatter, freeform content in body. Reuses the security constraints from `Brain.Entity` (YAML anchor rejection, frontmatter size limits) without coupling to schema validation.

### Modified Capabilities

_None._

## Impact

- **lib/goodwizard/memory/entry.ex** (new) — shared parser/serializer module
- **lib/goodwizard/memory/paths.ex** (modified) — add `episodic_dir/1`, `procedural_dir/1`, `episode_path/2`, `procedure_path/2`, `validate_memory_subdir/2`
- **Dependencies**: None — uses `yaml_elixir` which is already in the project
- **Existing code**: No modifications to actions, plugins, or brain modules — purely additive
- **Depends on**: Nothing (first in the series)
