## Why

With `brain-foundation` providing path helpers, ID generation, and schema validation, we need a storage layer that reads and writes entity files and exposes a clean CRUD API. This change bridges the infrastructure layer and the agent-facing actions by providing `Goodwizard.Brain` as a programmatic API for creating, reading, updating, deleting, and listing entities.

## What Changes

- Create `Goodwizard.Brain.Entity` module for parsing and serializing markdown files with YAML frontmatter
- Create `Goodwizard.Brain` public API module with `create/4`, `read/3`, `update/4`, `delete/3`, `list/2` functions that delegate to Schema, Entity, Id, and Paths modules

## Capabilities

### New Capabilities
- `brain-entity-format`: Parse and serialize entity files using markdown with YAML frontmatter — structured data in frontmatter, freeform notes in body
- `brain-storage`: File-based entity CRUD using the brain directory structure, with schema validation on create and update

### Modified Capabilities
_None._

## Impact

- **Dependencies**: None — uses modules from `brain-foundation`
- **Filesystem**: Creates entity type directories (e.g., `brain/people/`) and entity markdown files within them
- **Existing code**: No modifications to existing actions or plugins — purely additive
- **Depends on**: `brain-foundation`
