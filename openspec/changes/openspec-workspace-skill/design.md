## Context

Goodwizard is a Jido-based AI agent with a plugin/action architecture. It uses a workspace directory (`priv/workspace/`) to store brain entities, skills, memory, and sessions. The PromptSkills plugin demonstrates the pattern: scan a directory at mount time, build an index, inject a summary into the system prompt, and expose actions for on-demand loading.

OpenSpec is a spec-driven development framework that organizes project requirements as markdown files with structured sections (requirements + scenarios). Specs live at `openspec/specs/<capability>/spec.md` and changes live at `openspec/changes/<name>/`. The agent needs to understand these specs as first-class knowledge — not just raw files, but structured requirements it can reason about.

The user wants per-project spec management in the workspace, meaning the workspace can hold specs for multiple projects (e.g., `workspace/openspec/goodwizard/`, `workspace/openspec/client-app/`).

## Goals / Non-Goals

**Goals:**
- Give the agent awareness of project specs via system prompt injection
- Let the agent discover, list, read, and search specs across projects
- Support per-project organization within the workspace
- Follow existing Goodwizard patterns (plugin + actions + skill)
- Read OpenSpec markdown directly — no dependency on the `openspec` CLI binary

**Non-Goals:**
- Writing/creating new specs (read-only in v1 — users manage specs via OpenSpec CLI or editor)
- Running OpenSpec CLI commands on behalf of the user
- Validating spec syntax or enforcing OpenSpec schema rules
- Syncing specs between workspace and project `openspec/` directories (manual copy for now)
- Managing changes lifecycle (propose/apply/archive) — that's the existing `/opsx:*` skills

## Decisions

### 1. Plugin + Actions architecture (not standalone skill)

**Choice**: New `Goodwizard.Plugins.OpenSpec` plugin that scans workspace at mount time, plus action modules for on-demand operations.

**Why over standalone skill**: Skills are markdown prompt templates — good for instructions but can't scan filesystems or maintain state. A plugin can build a live index at startup and inject it into the system prompt, matching the PromptSkills pattern exactly.

**Alternatives considered**:
- Brain entities for specs — too much ceremony (JSON schemas, UUIDs, frontmatter) for what are plain markdown files with their own structure
- Pure actions without plugin — loses the startup scanning and prompt injection

### 2. Workspace directory layout: `workspace/openspec/<project>/`

**Choice**: Mirror OpenSpec's own structure per project:
```
workspace/openspec/
├── goodwizard/
│   ├── specs/
│   │   ├── auth/spec.md
│   │   └── messaging/spec.md
│   └── changes/
│       └── add-feature/
│           ├── proposal.md
│           └── specs/auth/spec.md
├── client-app/
│   └── specs/
│       └── api/spec.md
└── ...
```

**Why**: Preserves OpenSpec's native layout so files can be copied to/from project `openspec/` directories without transformation. Users familiar with OpenSpec will recognize the structure immediately.

**Alternatives considered**:
- Flat layout (`workspace/openspec/specs/project--capability.md`) — loses the natural hierarchy and breaks mental model
- Single project only — too limiting for users managing multiple projects

### 3. Read-only in v1

**Choice**: The plugin and actions only read/index/search specs. No write operations.

**Why**: Spec authoring is already handled well by the OpenSpec CLI and the `/opsx:*` skills. Adding write support means handling delta spec merging, validation, and sync — complexity that can come later once the read path proves valuable.

### 4. Markdown parsing: lightweight regex-based extraction

**Choice**: Parse spec files using pattern matching on `### Requirement:` and `#### Scenario:` headers. No full markdown AST.

**Why**: OpenSpec specs follow a predictable structure (RFC 2119 keywords, Given/When/Then scenarios). A regex approach is simpler, faster, and sufficient for indexing and search. The PromptSkills parser uses a similar lightweight approach for YAML frontmatter.

**Alternatives considered**:
- Full markdown parser (Earmark) — heavier dependency, overkill for structured headers
- YAML frontmatter on spec files — would require modifying OpenSpec's format

### 5. System prompt injection: project summary with requirement counts

**Choice**: The plugin injects a compact summary into the system prompt listing each project, its capability areas, and requirement counts. Full spec content is loaded on-demand via actions.

**Why**: Keeps the system prompt lean (following PromptSkills pattern) while giving the agent enough awareness to know what specs exist and when to consult them.

Format:
```
## OpenSpec Projects
- goodwizard: auth (5 requirements), messaging (3 requirements), brain (8 requirements)
- client-app: api (4 requirements)
```

## Risks / Trade-offs

**[Large workspace scan at startup]** → Keep the scan non-recursive at the project level (only enumerate `specs/*/spec.md`). Cache results. Startup cost should be minimal for <50 spec files.

**[Stale index after manual file edits]** → Accept staleness within a session. Plugin state is rebuilt on next agent startup. Could add a `refresh_specs` action later if needed.

**[No write path means manual spec management]** → Acceptable for v1. Users already manage specs via OpenSpec CLI. The agent's value is in reading and reasoning, not authoring.

**[Per-project isolation vs. cross-project search]** → Support both. Actions accept an optional `project` filter; omitting it searches across all projects.
