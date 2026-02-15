## Why

Goodwizard currently stores unstructured long-term memory in flat markdown files, with no schema validation or entity modeling. Before building a full knowledge system, we need the foundational infrastructure: dependencies, path management, ID generation, schema validation, and default schema definitions.

This change delivers the bottom layer that `brain-entity-storage` and `brain-agent-actions` will build on.

## What Changes

- Add `ex_json_schema` dependency for JSON Schema draft 7 validation
- Add `sqids` dependency for short, unique ID generation
- Create `Goodwizard.Brain.Paths` module for safe workspace-relative path helpers
- Create `Goodwizard.Brain.Id` module for Sqids-based entity ID generation with monotonic counter
- Create `Goodwizard.Brain.Schema` module for schema loading, validation, saving, and type listing
- Create `Goodwizard.Brain.Seeds` module to ship and seed 6 default entity type schemas (people, places, events, notes, tasks, companies)

## Capabilities

### New Capabilities
- `brain-paths`: Safe workspace-relative path helpers for the brain directory structure, with traversal rejection
- `brain-ids`: Sqids-based short unique ID generation with monotonic counter file
- `brain-schemas`: JSON Schema definitions and validation for entity types, stored in `brain/schemas/`
- `brain-seeds`: Default schema seeding for 6 initial entity types

### Modified Capabilities
_None — this is a new standalone subsystem._

## Impact

- **Dependencies**: New deps `ex_json_schema` for JSON Schema validation and `sqids` for ID generation
- **Filesystem**: Creates `brain/` tree under workspace with `schemas/` subdir and `.counter` file
- **Existing code**: No modifications to existing actions or plugins — purely additive
