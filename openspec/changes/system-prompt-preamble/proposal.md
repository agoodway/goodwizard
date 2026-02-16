## Why

The system prompt is assembled entirely from workspace markdown files (`IDENTITY.md`, `SOUL.md`, etc.) and runtime injections (brain awareness, skills, memory). There is no code-controlled preamble that orients the agent to its own system — what directories exist, what they're for, what conventions to follow. This foundational context currently lives nowhere or must be manually duplicated across workspace files.

A code-controlled preamble injected at the start of the system prompt ensures the agent always has accurate structural context regardless of what workspace files say, and it stays in sync with code changes automatically.

## What Changes

- Add a new module that generates a preamble string describing the system's workspace layout, directory purposes, and key conventions
- Modify the Hydrator to inject this preamble as the first content in the system prompt, before bootstrap files and other knowledge
- The preamble is read-only from the agent's perspective — workspace file edits cannot override it

## Capabilities

### New Capabilities
- `system-preamble`: Code-controlled preamble generation and injection into the system prompt

### Modified Capabilities

None — no existing specs to modify.

## Impact

- `lib/goodwizard/character/hydrator.ex` — new injection step at the start of the hydration pipeline
- New module `lib/goodwizard/character/preamble.ex` — generates the preamble string
- No API changes, no config changes, no breaking changes
- The system prompt grows by the preamble length (expected: a few hundred tokens)
