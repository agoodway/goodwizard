## Context

Goodwizard workspaces are initialized by `mix goodwizard.setup`, which creates top-level directories (`memory/`, `sessions/`, `skills/`, `brain/`) and bootstrap markdown files (`IDENTITY.md`, `SOUL.md`, etc.). The brain subsystem has its own `Brain.Seeds` module called during setup to create schema directories and seed default schemas.

The three-memory architecture (proposals 1-3) adds two new subdirectories -- `memory/episodic/` and `memory/procedural/` -- that must exist before any episodic or procedural memory operations can succeed. The system prompt preamble (`Goodwizard.Character.Preamble`) describes the workspace layout to orient the agent each turn. It currently lists `memory/` as a single-purpose directory.

## Goals / Non-Goals

**Goals:**

- `Memory.Seeds.seed/1` creates `memory/episodic/` and `memory/procedural/` directories, and ensures `memory/MEMORY.md` exists
- Seeding is idempotent -- safe to call multiple times without errors or data loss
- `mix goodwizard.setup` calls `Memory.Seeds.seed/1` so new workspaces are ready for all three memory types
- The preamble describes semantic, episodic, and procedural memory with enough detail for the agent to understand when and how to use each
- Preamble stays under the existing 10KB compile-time size limit

**Non-Goals:**

- No runtime directory creation on first write -- we rely on setup/seed, not lazy initialization
- No migration of existing workspaces -- users run `mix goodwizard.setup` again or create the directories manually
- No changes to MEMORY.md content or format -- just ensure the file exists
- No changes to session or brain seeding

## Decisions

### 1. Separate `Memory.Seeds` module rather than inline in setup task

Create `lib/goodwizard/memory/seeds.ex` as a standalone module, mirroring the `Brain.Seeds` pattern already established. The setup task calls it, but it can also be called programmatically (e.g., in tests or future migration scripts).

**Why over alternatives:**
- *Inline in setup task* -- mixes concerns; the setup task would need memory-specific knowledge
- *Auto-create on first write* -- hides initialization failures, adds latency to hot paths, and makes the system harder to reason about

### 2. Use `File.mkdir_p!/1` for directory creation

Use the bang variant inside `seed/1`. If the filesystem is broken enough that `mkdir_p` fails, there is no graceful recovery -- the workspace is unusable. Failing loudly at setup time is better than silent runtime failures.

**Why over `File.mkdir_p/1` with error tuples:** Seeding runs at setup time, not in the agent hot loop. A crash here is appropriate and informative.

### 3. Seed MEMORY.md only if missing

Write an empty string to `MEMORY.md` only when the file does not exist. This preserves any existing memory profile content. The file is the semantic memory profile and may have been populated by the agent or user.

**Why not always write:** Overwriting would destroy learned preferences and facts. The seed is a safety net, not a reset.

### 4. Preamble describes three memory types with usage guidance

Expand the `memory/` line in the preamble into a structured "Memory System" subsection listing all three types with their purpose, storage location, and behavioral guidance. This gives the agent enough context to decide which memory type to use without reading additional documentation.

**Why over a minimal description:** The agent sees the preamble every turn. Richer memory guidance here means the agent naturally reaches for the right memory type without prompt engineering in each skill or action description.

### 5. Keep preamble as a compile-time constant

The preamble remains a `@preamble` module attribute evaluated at compile time. The expanded memory section adds roughly 400-500 bytes, well within the 10KB limit. No need to switch to runtime generation.

**Why over runtime generation:** No dynamic content in the preamble. Compile-time catches formatting errors early and has zero runtime cost.

## Risks / Trade-offs

- **Existing workspaces need manual update** -- Users with existing workspaces must run `mix goodwizard.setup` again or manually create the two directories. This is consistent with how brain schema updates work. The agent will get clear error messages ("directory not found") if the directories are missing, which is better than silent failures.

- **Preamble size increase** -- The expanded memory section adds to every system prompt. At ~500 bytes, this is negligible relative to the typical 2-4KB preamble and the 8K+ token context window. The compile-time 10KB guard prevents accidental bloat.

- **Coupling between Seeds and directory structure** -- If the memory directory layout changes, Seeds must be updated. This is acceptable since the layout is defined in the plan document and unlikely to change within this series.
