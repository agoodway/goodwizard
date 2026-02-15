## Why

Goodwizard currently stores unstructured long-term memory in flat markdown files, with no schema validation or entity modeling. A structured knowledge system would let the agent remember, retrieve, and relate typed entities (people, companies, events, etc.) with validated data — turning freeform notes into a queryable personal knowledge base.

## What Changes

- Add `ex_json_schema` dependency for JSON Schema draft 4/6/7 validation
- Add `sqids` dependency for short, unique ID generation
- Create a `brain/` directory structure in the workspace with subdirs per entity type and a `schemas/` subdir for JSON Schema definitions
- Store each entity as a markdown file with YAML frontmatter (serialized from its JSON Schema), allowing both structured data and freeform notes
- Build a `Goodwizard.Brain` module for schema-validated CRUD operations on entity files
- Ship initial schemas for 6 entity types: people, places, events, notes, tasks, companies
- Support creating new entity types by defining a new JSON Schema

## Capabilities

### New Capabilities
- `brain-storage`: File-based entity storage using markdown files with YAML frontmatter, organized by entity type in workspace `brain/` directory
- `brain-schemas`: JSON Schema definitions and validation for entity types, stored in `brain/schemas/`, with support for creating and updating schemas
### Modified Capabilities
_None — this is a new standalone subsystem._

## Impact

- **Dependencies**: New deps `ex_json_schema` for JSON Schema validation and `sqids` for ID generation
- **Filesystem**: Creates `brain/` tree under workspace with `schemas/`, `people/`, `places/`, `events/`, `notes/`, `tasks/`, `companies/` subdirs
- **Agent tools**: New Jido actions for brain CRUD and schema operations registered in agent tool list
- **Existing code**: No modifications to existing actions or plugins — purely additive
