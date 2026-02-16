## Context

Goodwizard's Workflow runtime lets the agent run multi-step tool sequences as a single deterministic operation with explicit approval checkpoints. Before building parsers, runners, or actions, we need the core data types that every other Workflow module will depend on.

No existing workflow code exists in the project. The agent is built on the Jido framework in Elixir. The only dependency for this change is Jason (already present) for the Envelope module's JSON-encodable maps.

## Goals / Non-Goals

**Goals:**

- Define `Step`, `Pipeline`, and `ApprovalRequest` structs as the shared vocabulary for all Workflow modules
- Define an `Envelope` formatter module producing three structured output shapes (`ok`, `needs_approval`, `cancelled`)
- Keep all modules pure data — no IO, no GenServers, no side effects
- Make structs enforceable with `@enforce_keys` for required fields

**Non-Goals:**

- Execution logic (runner handles this)
- Parsing logic (parsers handle this)
- Persistence or serialization (state module handles this)
- Validation of field values beyond struct enforcement

## Decisions

### 1. Separate module per struct

Each struct gets its own module file: `Step`, `Pipeline`, `ApprovalRequest`. This follows the Elixir convention of one struct per module and keeps each file focused and small.

**Alternative considered**: Single `Types` module with multiple structs via inner modules. Rejected because Elixir doesn't have inner module scoping — `defmodule` nesting is cosmetic, and separate files are clearer.

### 2. Step type as atom enum

Step types are atoms: `:exec`, `:approve`, `:openclaw_invoke`. Pattern matching on atoms is idiomatic Elixir and avoids string comparison overhead.

### 3. Pipeline holds step list plus execution metadata

The `Pipeline` struct contains `steps` (ordered list), `name` (optional), `timeout_ms` (integer), and `max_stdout_bytes` (integer). Default values are set so parsers only need to populate what they extract from input.

### 4. Envelope returns plain maps, not structs

The `Envelope` module returns Jason-encodable maps (not structs) because the output is serialized to JSON for the LLM. Using plain maps avoids needing `Jason.Encoder` implementations.

### 5. ApprovalRequest carries enough context for resume

`ApprovalRequest` includes `prompt`, `preview_items` (list of strings), `token` (resume token), and `step_index` (which step triggered the halt). This gives the LLM everything it needs to present the approval gate to the user.

## Risks / Trade-offs

- **Struct evolution**: Adding fields to structs later requires updating all call sites that pattern-match on the full struct. Mitigated by keeping struct creation in factory functions within each module.
- **No runtime validation**: Structs enforce keys at compile time but don't validate types at runtime. Acceptable because parsers validate before constructing structs.
