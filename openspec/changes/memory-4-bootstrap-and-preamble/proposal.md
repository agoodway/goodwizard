## Why

The new episodic and procedural memory stores (proposals 2 and 3) introduce subdirectories under `memory/` that do not exist in a fresh workspace. Without bootstrap logic, the first attempt to write an episode or procedure will fail with a missing-directory error. Additionally, the system prompt preamble still describes `memory/` as a single flat directory for "long-term conversation memory," giving the agent no awareness of its three-memory architecture or guidance on when to use each type.

This is proposal 4 of 9 in the memory system series. The full plan is documented in `docs/memory-system-plan.md`.

## What Changes

- Create `Goodwizard.Memory.Seeds` module that ensures `memory/episodic/` and `memory/procedural/` directories exist and that `memory/MEMORY.md` is present
- Update `Mix.Tasks.Goodwizard.Setup` to call `Memory.Seeds.seed/1` during workspace initialization, so new projects get the directory structure automatically
- Update `Goodwizard.Character.Preamble` to replace the single-line memory description with a structured three-memory-type orientation section (semantic, episodic, procedural)
- Update preamble tests to assert on the new memory system description

## Capabilities

### New Capabilities

- `memory-bootstrap`: Directory seeding and preamble orientation for the three-memory architecture

### Modified Capabilities

_(none -- this is infrastructure plumbing, not modifying existing behavioral specs)_

## Impact

- **New module**: `lib/goodwizard/memory/seeds.ex` -- directory bootstrapping
- **Modified**: `lib/mix/tasks/goodwizard.setup.ex` -- calls `Memory.Seeds.seed/1` after existing directory setup
- **Modified**: `lib/goodwizard/character/preamble.ex` -- expanded memory section in preamble text
- **Modified**: `test/goodwizard/character/preamble_test.exs` -- updated assertions for new preamble content
- **New tests**: `test/goodwizard/memory/seeds_test.exs` -- seed idempotency and directory creation

## Prerequisites

- `memory-2-episodic-store` -- the `Memory.Episodic` module that reads/writes to `memory/episodic/`
- `memory-3-procedural-store` -- the `Memory.Procedural` module that reads/writes to `memory/procedural/`
