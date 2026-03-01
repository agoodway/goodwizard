## Why

Goodwizard currently has no understanding of OpenSpec — the spec-driven development framework it uses for change management. When users ask the agent to work with specs, review requirements, or understand what a project's current behavior should be, the agent has no built-in way to discover, read, or reason about OpenSpec specs. This means users must manually copy-paste spec content into conversations or rely on file reads without structured understanding. Adding a first-class OpenSpec skill lets Goodwizard manage specs per-project in the workspace, making requirements a natural part of the agent's knowledge — just like brain entities and memory.

## What Changes

- New **OpenSpec plugin** that scans workspace `openspec/` directories at agent startup and builds an index of projects, specs, and active changes
- New **actions** for CRUD operations on specs: list projects, read specs, search across specs, show change status, and validate specs
- New **prompt skill** (`openspec`) with documentation on how the agent should use OpenSpec concepts when reasoning about requirements
- New **workspace directory structure** at `workspace/openspec/<project>/` that mirrors the OpenSpec layout (specs/, changes/) per project
- System prompt injection via the plugin so the agent is always aware of available specs and active changes

## Capabilities

### New Capabilities
- `spec-discovery`: Scanning, indexing, and listing OpenSpec specs and changes across workspace projects
- `spec-management`: Reading, searching, and navigating spec content (requirements, scenarios, delta specs)
- `spec-awareness`: System prompt integration that gives the agent contextual awareness of project requirements

### Modified Capabilities
None — this is entirely new functionality.

## Impact

- **New files**: Plugin module, 3-4 action modules, prompt skill markdown, workspace directory scaffold
- **Modified files**: Agent setup (to mount new plugin), Config module (new `openspec` config section), preamble (to reference openspec directory)
- **Dependencies**: None — reads OpenSpec markdown files directly, no dependency on `openspec` CLI
- **Workspace**: Adds `openspec/` directory to workspace alongside existing `brain/`, `skills/`, `memory/`
