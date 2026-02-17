## Why

The procedural memory store (proposal 3) provides a core module for creating, reading, updating, searching, and tracking usage of learned procedures, but the agent cannot access these operations without Jido actions wrapping them. Without these actions, the agent cannot learn new procedures from successful interactions, recall relevant procedures when facing a familiar task, refine procedures based on new experience, or track which procedures work well and which do not. The usage tracking and confidence adjustment system -- procedural memory's key differentiator from episodic memory -- is entirely inaccessible to the agent without the `UseProcedure` action.

This is proposal 6 of 9 in the memory system series. The full plan is documented in `docs/memory-system-plan.md`.

## What Changes

- Create 5 Jido actions under `lib/goodwizard/actions/memory/procedural/`:
  - `LearnProcedure` -- create a new procedure with trigger conditions, steps, and metadata
  - `RecallProcedures` -- find procedures relevant to a described situation using scored ranking
  - `UpdateProcedure` -- modify an existing procedure's steps, confidence, or other fields
  - `UseProcedure` -- mark a procedure as used and record the outcome, adjusting confidence
  - `ListProcedures` -- list all procedures with optional type and confidence filters
- Register all 5 actions in `Goodwizard.Agent`'s `tools:` list
- Each action resolves the memory directory from context (with Config fallback per project conventions) and delegates to `Goodwizard.Memory.Procedural`

## Capabilities

### New Capabilities

- `procedural-actions`: Five Jido actions (LearnProcedure, RecallProcedures, UpdateProcedure, UseProcedure, ListProcedures) that expose the procedural memory store as agent tools

### Modified Capabilities

_(none -- this adds new actions without changing existing memory action behavior)_

## Impact

- **New modules**: 5 action modules under `lib/goodwizard/actions/memory/procedural/`
- **Modified**: `lib/goodwizard/agent.ex` -- add 5 new tool entries to the `tools:` list
- **New tests**: Integration tests for each action under `test/goodwizard/actions/memory/procedural/`
- **Dependency**: Relies on `Goodwizard.Memory.Procedural` module from proposal 3 and bootstrapped directories from proposal 4

## Prerequisites

- `memory-3-procedural-store` -- the `Memory.Procedural` core module with CRUD, recall, and usage tracking
- `memory-4-bootstrap-and-preamble` -- directory bootstrapping ensures `memory/procedural/` exists
