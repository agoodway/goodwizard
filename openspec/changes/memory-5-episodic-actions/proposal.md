## Why

The episodic memory store (proposal 2) provides a core module for creating, reading, searching, and listing episode records, but the agent has no way to invoke these operations. Without Jido actions wrapping the store, the agent cannot record what happened during a conversation, search for similar past experiences, or review its history of notable events. These actions are the bridge between the LLM's tool-calling interface and the file-backed episodic store.

This is proposal 5 of 9 in the memory system series. The full plan is documented in `docs/memory-system-plan.md`.

## What Changes

- Create 4 Jido actions under `lib/goodwizard/actions/memory/episodic/`:
  - `RecordEpisode` -- record a notable experience with structured observation/approach/result/lessons
  - `SearchEpisodes` -- search past experiences by text query, tags, type, or outcome
  - `ReadEpisode` -- read a specific episode by ID
  - `ListEpisodes` -- list recent episodes with optional filters
- Register all 4 actions in `Goodwizard.Agent`'s `tools:` list
- Each action resolves the memory directory from context (with Config fallback per project conventions) and delegates to `Goodwizard.Memory.Episodic`

## Capabilities

### New Capabilities

- `episodic-actions`: Four Jido actions (RecordEpisode, SearchEpisodes, ReadEpisode, ListEpisodes) that expose the episodic memory store as agent tools

### Modified Capabilities

_(none -- this adds new actions without changing existing memory action behavior)_

## Impact

- **New modules**: 4 action modules under `lib/goodwizard/actions/memory/episodic/`
- **Modified**: `lib/goodwizard/agent.ex` -- add 4 new tool entries to the `tools:` list
- **New tests**: Integration tests for each action under `test/goodwizard/actions/memory/episodic/`
- **Dependency**: Relies on `Goodwizard.Memory.Episodic` module from proposal 2 and bootstrapped directories from proposal 4

## Prerequisites

- `memory-2-episodic-store` -- the `Memory.Episodic` core module with CRUD and search operations
- `memory-4-bootstrap-and-preamble` -- directory bootstrapping ensures `memory/episodic/` exists
