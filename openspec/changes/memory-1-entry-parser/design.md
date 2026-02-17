## Context

Goodwizard is implementing a three-memory architecture (semantic, episodic, procedural) as described in `docs/memory-system-plan.md`. This is the first change in a 9-proposal series.

The brain already uses `Brain.Entity` for markdown+YAML parsing, but that module is coupled to brain-specific concerns: JSON Schema validation, `stringify_keys` for brain data maps, and entity-specific serialization. Episodic and procedural memories need a simpler parser that enforces security constraints (no YAML anchors, size limits) without schema validation — field requirements are enforced at the action level.

The existing `Memory.Paths` module provides `history_path/1`, `memory_path/1`, `ensure_dir/1`, and `validate_memory_dir/1`. It needs to be extended with path helpers for the new `episodic/` and `procedural/` subdirectories.

Key files:
- `lib/goodwizard/brain/entity.ex` — existing parser (reference implementation, not modified)
- `lib/goodwizard/memory/paths.ex` — existing path helpers (modified)
- `lib/goodwizard/memory/entry.ex` — new shared parser

## Goals / Non-Goals

**Goals:**
- Parse markdown files with YAML frontmatter into `{frontmatter_map, body_string}` tuples
- Serialize frontmatter maps + body strings back into markdown with YAML frontmatter
- Enforce security constraints: reject YAML anchors/aliases, limit frontmatter size (64 KB), limit body size (1 MB)
- Provide path helpers for episodic and procedural memory subdirectories
- Validate subdirectory paths to prevent traversal

**Non-Goals:**
- JSON Schema validation (handled at the action layer, not the parser)
- CRUD operations (handled by `Memory.Episodic` and `Memory.Procedural` in proposals 2 and 3)
- Directory bootstrapping or seeding (handled in proposal 4)
- Any brain module changes

## Decisions

### 1. Separate module from Brain.Entity

Create `Memory.Entry` as a standalone module rather than extracting shared code from `Brain.Entity` into a common base.

**Rationale:** `Brain.Entity` has brain-specific behaviors (key stringification, specific error atoms, tight coupling to the schema validation pipeline). Extracting a shared base would require refactoring `Brain.Entity` and all its callers, which is risky and out of scope. `Memory.Entry` is small (~80 LOC) — the duplication is acceptable and the two modules can evolve independently.

**Alternative considered:** Extract `Goodwizard.FileFormat.Frontmatter` as a shared module used by both `Brain.Entity` and `Memory.Entry`. Rejected because the divergence in behavior (schema validation, key handling) means the shared surface would be minimal and the abstraction would be leaky.

### 2. Size limits on both frontmatter and body

Enforce a 64 KB max frontmatter size and a 1 MB max body size. These are checked before YAML parsing to prevent memory exhaustion from malicious or corrupted files.

**Rationale:** `Brain.Entity` already enforces the 64 KB frontmatter limit. Adding a body limit is new — it prevents a single memory file from consuming excessive memory during bulk operations (e.g., listing all episodes). 1 MB is generous for any reasonable memory entry.

**Alternative considered:** No body size limit. Rejected because procedural recall and episodic search scan all files, so an unbounded file could cause latency spikes.

### 3. String keys in frontmatter maps

`Memory.Entry.parse/1` returns frontmatter maps with string keys (matching `Brain.Entity`'s behavior). This avoids atom exhaustion from user-controlled YAML keys.

**Rationale:** YAML keys from files are untrusted input. Converting to atoms could exhaust the atom table. String keys are safe and consistent with the brain layer.

### 4. Path helpers follow Brain.Paths pattern

New path functions in `Memory.Paths` follow the same pattern as `Brain.Paths`: pure functions that construct paths without side effects. Directory creation is left to the caller or the seeds module.

**Rationale:** Separation of concerns. Path construction is pure; filesystem operations belong in the module that owns the lifecycle.

### 5. Subdirectory validation restricts to known names

`validate_memory_subdir/2` accepts only `"episodic"` and `"procedural"` as valid subdirectory names. This prevents arbitrary subdirectory traversal through the memory path helpers.

**Rationale:** The set of memory subdirectories is fixed by design. Restricting to a known set is more secure than pattern-based validation.

## Risks / Trade-offs

**Code duplication with Brain.Entity** — The YAML parsing logic, anchor rejection, and serialization overlap ~60% with `Brain.Entity`. If a bug is found in one, it must be fixed in both. Mitigation: both modules are small and well-tested. A future refactor could extract a shared base if the duplication becomes a maintenance burden.

**YAML serialization is naive** — The serializer uses simple inline YAML formatting (same approach as `Brain.Entity`). Complex nested structures may not round-trip perfectly. Mitigation: memory frontmatter is flat by design (strings, lists of strings, integers, timestamps). Deep nesting is not expected or encouraged.

**No migration path for existing memory files** — This parser is new, and there are no existing episodic/procedural files to migrate. If the frontmatter format changes later, entries would need a migration. Mitigation: the format is intentionally simple and flexible, reducing the likelihood of breaking changes.
