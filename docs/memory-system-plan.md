# Three-Memory Architecture Implementation Plan

## Overview

Replace Goodwizard's flat memory system with a cognitive-science-inspired architecture using three memory types: **Semantic** (brain — unchanged), **Episodic** (structured experience records), and **Procedural** (learned behavioral patterns). All storage remains markdown+YAML. No new dependencies.

### References

- [LangMem Conceptual Guide](https://langchain-ai.github.io/langmem/concepts/conceptual_guide/)
- [MIRIX Multi-Agent Memory System](https://arxiv.org/pdf/2507.07957)
- [MemAgents ICLR 2026 Workshop](https://openreview.net/pdf?id=U51WxL382H)

### Architecture Summary

| Memory Type | Purpose | Storage | Existing? |
|---|---|---|---|
| **Semantic** | Facts & knowledge | `brain/` (collection) + `memory/MEMORY.md` (profile) | Yes — no changes |
| **Episodic** | Past experiences | `memory/episodic/<uuid7>.md` | New |
| **Procedural** | Learned procedures | `memory/procedural/<uuid7>.md` | New |
| **Working** | Current conversation | `sessions/<key>.jsonl` | Yes — no changes |

---

## Phase 1: Foundation

### 1.1 Create `Memory.Entry` module

**File:** `lib/goodwizard/memory/entry.ex`

Shared parser/serializer for episodic and procedural memory files. Similar to `Brain.Entity` but simpler — no JSON Schema validation.

```elixir
defmodule Goodwizard.Memory.Entry do
  @moduledoc """
  Parse and serialize markdown memory entries with YAML frontmatter.
  Used by both episodic and procedural memory systems.
  """

  @max_frontmatter_size 64 * 1024  # 64 KB
  @max_body_size 1024 * 1024       # 1 MB

  @type frontmatter :: map()
  @type body :: String.t()

  @doc "Parse a markdown file into {frontmatter_map, body_string}"
  @spec parse(String.t()) :: {:ok, {frontmatter(), body()}} | {:error, term()}

  @doc "Serialize a frontmatter map and body string into markdown"
  @spec serialize(frontmatter(), body()) :: String.t()
end
```

**Implementation details:**
- Reuse YAML parsing approach from `Brain.Entity` (reject anchors, max frontmatter size)
- `parse/1` — split on `---` fences, decode YAML frontmatter, return `{map, body}`
- `serialize/2` — encode map to YAML, wrap in fences, append body
- No schema validation — entries are flexible by design
- Validate required fields per type at the action level, not here

### 1.2 Create `Memory.Episodic` module

**File:** `lib/goodwizard/memory/episodic.ex`

Core CRUD + search for episodic memory.

```elixir
defmodule Goodwizard.Memory.Episodic do
  @moduledoc "Episodic memory store — structured records of past experiences."

  alias Goodwizard.Memory.{Entry, Paths}
  alias Goodwizard.Brain.Id

  # --- Types ---

  @episode_types ~w(task_completion problem_solved error_encountered decision_made interaction)
  @outcome_types ~w(success failure partial abandoned)

  # --- CRUD ---

  @doc "Create a new episode. Auto-generates id and timestamp."
  @spec create(String.t(), map(), String.t()) :: {:ok, map()} | {:error, term()}
  def create(memory_dir, frontmatter, body)

  @doc "Read an episode by ID."
  @spec read(String.t(), String.t()) :: {:ok, {map(), String.t()}} | {:error, term()}
  def read(memory_dir, id)

  @doc "List episodes with optional filters."
  @spec list(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def list(memory_dir, opts \\ [])
  # opts: limit (default 20), type, outcome, tags, after (datetime), before (datetime)

  @doc "Delete an episode by ID."
  @spec delete(String.t(), String.t()) :: :ok | {:error, term()}
  def delete(memory_dir, id)

  # --- Search ---

  @doc "Search episodes by text query across frontmatter and body."
  @spec search(String.t(), String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def search(memory_dir, query, opts \\ [])
  # opts: limit (default 10), type, outcome, tags
end
```

**Episode frontmatter schema (enforced in create, not JSON Schema):**

```yaml
id: <uuid7>                    # auto-generated
timestamp: <iso8601>           # auto-generated
type: <episode_type>           # required
summary: <string>              # required, max 200 chars
tags: [<string>, ...]          # optional, default []
outcome: <outcome_type>        # required
entities_involved: [<ref>, ...]# optional, default []
```

**Episode body sections (convention, not enforced):**

```markdown
## Observation
What was the situation?

## Approach
What was tried?

## Result
What happened?

## Lessons
What to remember?
```

**Search implementation:**
1. List all `.md` files in `memory/episodic/`
2. Parse frontmatter only (fast — skip body unless text query)
3. Apply filters: type, outcome, tags (intersection), date range
4. If text query provided, also search body content (case-insensitive substring)
5. Sort by timestamp descending (most recent first)
6. Apply limit

### 1.3 Create `Memory.Procedural` module

**File:** `lib/goodwizard/memory/procedural.ex`

Core CRUD + search + usage tracking for procedural memory.

```elixir
defmodule Goodwizard.Memory.Procedural do
  @moduledoc "Procedural memory store — learned behavioral patterns and workflows."

  alias Goodwizard.Memory.{Entry, Paths}
  alias Goodwizard.Brain.Id

  # --- Types ---

  @procedure_types ~w(workflow preference rule strategy tool_usage)
  @confidence_levels ~w(high medium low)
  @source_types ~w(learned taught inferred)

  # --- CRUD ---

  @doc "Create a new procedure."
  @spec create(String.t(), map(), String.t()) :: {:ok, map()} | {:error, term()}
  def create(memory_dir, frontmatter, body)

  @doc "Read a procedure by ID."
  @spec read(String.t(), String.t()) :: {:ok, {map(), String.t()}} | {:error, term()}
  def read(memory_dir, id)

  @doc "Update a procedure's frontmatter and/or body."
  @spec update(String.t(), String.t(), map(), String.t() | nil) :: {:ok, map()} | {:error, term()}
  def update(memory_dir, id, frontmatter_updates, body \\ nil)

  @doc "List procedures with optional filters."
  @spec list(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def list(memory_dir, opts \\ [])
  # opts: limit (default 20), type, confidence, tags, min_usage_count

  @doc "Delete a procedure by ID."
  @spec delete(String.t(), String.t()) :: :ok | {:error, term()}
  def delete(memory_dir, id)

  # --- Search ---

  @doc "Find procedures relevant to a given situation."
  @spec recall(String.t(), String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def recall(memory_dir, situation, opts \\ [])
  # opts: limit (default 5), type, tags, min_confidence

  # --- Usage Tracking ---

  @doc "Record that a procedure was used. Adjusts confidence based on outcome."
  @spec record_usage(String.t(), String.t(), :success | :failure) :: {:ok, map()} | {:error, term()}
  def record_usage(memory_dir, id, outcome)
end
```

**Procedure frontmatter schema:**

```yaml
id: <uuid7>                    # auto-generated
created_at: <iso8601>          # auto-generated
updated_at: <iso8601>          # auto-generated/updated
type: <procedure_type>         # required
summary: <string>              # required, max 200 chars
tags: [<string>, ...]          # optional, default []
confidence: <confidence_level> # required, default "medium"
source: <source_type>          # required
usage_count: <integer>         # auto-managed, starts at 0
last_used: <iso8601> | null    # auto-managed
```

**Procedure body sections (convention):**

```markdown
## When to apply
Trigger conditions — what situation should activate this procedure.

## Steps
1. Step one
2. Step two
3. ...

## Notes
Caveats, variations, edge cases.
```

**Usage tracking / confidence adjustment:**
- On `record_usage(id, :success)`: increment `usage_count`, update `last_used`, promote confidence (low→medium after 3 successes, medium→high after 5)
- On `record_usage(id, :failure)`: increment `usage_count`, update `last_used`, demote confidence (high→medium after 2 failures, medium→low after 3)
- Track success/failure ratio internally (could add `success_count` and `failure_count` fields)

**Recall scoring:**
```
score = tag_match_score * 0.4
      + text_relevance * 0.3
      + confidence_score * 0.2   # high=1.0, medium=0.6, low=0.3
      + recency_score * 0.1      # decays over time from last_used
```
Sort by score descending.

### 1.4 Update `Memory.Paths`

**File:** `lib/goodwizard/memory/paths.ex` (existing)

Add path helpers for the new subdirectories:

```elixir
# Add to existing module:

def episodic_dir(memory_dir), do: Path.join(memory_dir, "episodic")
def procedural_dir(memory_dir), do: Path.join(memory_dir, "procedural")

def episode_path(memory_dir, id) do
  Path.join(episodic_dir(memory_dir), "#{id}.md")
end

def procedure_path(memory_dir, id) do
  Path.join(procedural_dir(memory_dir), "#{id}.md")
end

# Validate subdirectory segments
def validate_memory_subdir(memory_dir, subdir) when subdir in ~w(episodic procedural) do
  path = Path.join(memory_dir, subdir)
  if File.dir?(path), do: {:ok, path}, else: {:error, :not_found}
end
```

### 1.5 Update Seeds / Bootstrap

**File:** `lib/goodwizard/memory/seeds.ex` (new, or add to existing setup)

```elixir
defmodule Goodwizard.Memory.Seeds do
  @moduledoc "Bootstrap memory directory structure."

  def seed(workspace) do
    memory_dir = Path.join(workspace, "memory")

    for subdir <- ~w(episodic procedural) do
      path = Path.join(memory_dir, subdir)
      File.mkdir_p!(path)
    end

    # Ensure MEMORY.md exists
    memory_md = Path.join(memory_dir, "MEMORY.md")
    unless File.exists?(memory_md), do: File.write!(memory_md, "")

    :ok
  end
end
```

Also update `mix goodwizard.setup` to call this.

### 1.6 Update Preamble

**File:** `lib/goodwizard/character/preamble.ex`

Update the workspace orientation section to describe the three memory types:

```
### Memory System
Your memory is organized into three types, inspired by cognitive science:

- **Semantic Memory** (facts & knowledge)
  - `brain/` — Structured entities (people, notes, events, etc.) with schema validation
  - `memory/MEMORY.md` — Quick-reference profile of key facts about the user and context

- **Episodic Memory** (past experiences)
  - `memory/episodic/` — Structured records of notable past interactions
  - Each episode captures: what happened, what you tried, what worked/failed, and lessons learned
  - Use these to avoid repeating mistakes and to build on past successes

- **Procedural Memory** (how to do things)
  - `memory/procedural/` — Learned procedures, workflows, and behavioral patterns
  - Each procedure captures: when to apply it, step-by-step instructions, and confidence level
  - Procedures strengthen with successful use and weaken on failures
```

Also update `test/goodwizard/character/preamble_test.exs` to match.

---

## Phase 2: Actions

### 2.1 Episodic Memory Actions

**Directory:** `lib/goodwizard/actions/memory/episodic/`

#### `record_episode.ex`

```elixir
defmodule Goodwizard.Actions.Memory.Episodic.RecordEpisode do
  use Jido.Action,
    name: "record_episode",
    description: "Record a notable experience as an episodic memory",
    schema: [
      type: [type: {:in, ~w(task_completion problem_solved error_encountered decision_made interaction)a}, required: true],
      summary: [type: :string, required: true, doc: "One-line summary (max 200 chars)"],
      tags: [type: {:list, :string}, default: []],
      outcome: [type: {:in, ~w(success failure partial abandoned)a}, required: true],
      entities_involved: [type: {:list, :string}, default: []],
      observation: [type: :string, required: true, doc: "What was the situation?"],
      approach: [type: :string, required: true, doc: "What strategy/steps were taken?"],
      result: [type: :string, required: true, doc: "What happened?"],
      lessons: [type: :string, default: "", doc: "What to remember for the future?"]
    ]

  def run(params, context) do
    memory_dir = resolve_memory_dir(context)

    frontmatter = %{
      type: to_string(params.type),
      summary: String.slice(params.summary, 0, 200),
      tags: params.tags,
      outcome: to_string(params.outcome),
      entities_involved: params.entities_involved
    }

    body = """
    ## Observation
    #{params.observation}

    ## Approach
    #{params.approach}

    ## Result
    #{params.result}

    ## Lessons
    #{params.lessons}
    """

    case Goodwizard.Memory.Episodic.create(memory_dir, frontmatter, body) do
      {:ok, episode} -> {:ok, %{episode: episode, message: "Episode recorded: #{params.summary}"}}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

#### `search_episodes.ex`

```elixir
defmodule Goodwizard.Actions.Memory.Episodic.SearchEpisodes do
  use Jido.Action,
    name: "search_episodes",
    description: "Search past experiences by text, tags, outcome, or type",
    schema: [
      query: [type: :string, default: "", doc: "Text to search for in episodes"],
      tags: [type: {:list, :string}, default: [], doc: "Filter by tags"],
      type: [type: :string, doc: "Filter by episode type"],
      outcome: [type: :string, doc: "Filter by outcome (success/failure/partial/abandoned)"],
      limit: [type: :integer, default: 10, doc: "Max results to return"]
    ]

  def run(params, context) do
    memory_dir = resolve_memory_dir(context)
    opts = Keyword.new(Map.from_struct(params) |> Map.delete(:query) |> Enum.reject(fn {_, v} -> is_nil(v) end))

    case Goodwizard.Memory.Episodic.search(memory_dir, params.query, opts) do
      {:ok, episodes} -> {:ok, %{episodes: episodes, count: length(episodes)}}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

#### `read_episode.ex`

```elixir
defmodule Goodwizard.Actions.Memory.Episodic.ReadEpisode do
  use Jido.Action,
    name: "read_episode",
    description: "Read a specific episode by ID",
    schema: [
      id: [type: :string, required: true, doc: "Episode UUID"]
    ]

  def run(params, context) do
    memory_dir = resolve_memory_dir(context)

    case Goodwizard.Memory.Episodic.read(memory_dir, params.id) do
      {:ok, {frontmatter, body}} -> {:ok, %{frontmatter: frontmatter, body: body}}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

#### `list_episodes.ex`

```elixir
defmodule Goodwizard.Actions.Memory.Episodic.ListEpisodes do
  use Jido.Action,
    name: "list_episodes",
    description: "List recent episodes with optional filters",
    schema: [
      limit: [type: :integer, default: 20],
      type: [type: :string, doc: "Filter by episode type"],
      outcome: [type: :string, doc: "Filter by outcome"]
    ]

  def run(params, context) do
    memory_dir = resolve_memory_dir(context)
    opts = build_filter_opts(params)

    case Goodwizard.Memory.Episodic.list(memory_dir, opts) do
      {:ok, episodes} -> {:ok, %{episodes: episodes, count: length(episodes)}}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### 2.2 Procedural Memory Actions

**Directory:** `lib/goodwizard/actions/memory/procedural/`

#### `learn_procedure.ex`

```elixir
defmodule Goodwizard.Actions.Memory.Procedural.LearnProcedure do
  use Jido.Action,
    name: "learn_procedure",
    description: "Learn a new procedure — how to accomplish a type of task",
    schema: [
      type: [type: {:in, ~w(workflow preference rule strategy tool_usage)a}, required: true],
      summary: [type: :string, required: true, doc: "What this procedure is for (max 200 chars)"],
      tags: [type: {:list, :string}, default: []],
      confidence: [type: {:in, ~w(high medium low)a}, default: :medium],
      source: [type: {:in, ~w(learned taught inferred)a}, required: true],
      when_to_apply: [type: :string, required: true, doc: "Trigger conditions"],
      steps: [type: :string, required: true, doc: "Step-by-step instructions"],
      notes: [type: :string, default: "", doc: "Caveats or variations"]
    ]

  def run(params, context) do
    memory_dir = resolve_memory_dir(context)

    frontmatter = %{
      type: to_string(params.type),
      summary: String.slice(params.summary, 0, 200),
      tags: params.tags,
      confidence: to_string(params.confidence),
      source: to_string(params.source)
    }

    body = """
    ## When to apply
    #{params.when_to_apply}

    ## Steps
    #{params.steps}

    ## Notes
    #{params.notes}
    """

    case Goodwizard.Memory.Procedural.create(memory_dir, frontmatter, body) do
      {:ok, procedure} -> {:ok, %{procedure: procedure, message: "Procedure learned: #{params.summary}"}}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

#### `recall_procedures.ex`

```elixir
defmodule Goodwizard.Actions.Memory.Procedural.RecallProcedures do
  use Jido.Action,
    name: "recall_procedures",
    description: "Find procedures relevant to the current situation",
    schema: [
      situation: [type: :string, required: true, doc: "Describe the current situation or task"],
      tags: [type: {:list, :string}, default: []],
      type: [type: :string, doc: "Filter by procedure type"],
      limit: [type: :integer, default: 5]
    ]

  def run(params, context) do
    memory_dir = resolve_memory_dir(context)
    opts = [limit: params.limit, type: params.type, tags: params.tags]

    case Goodwizard.Memory.Procedural.recall(memory_dir, params.situation, opts) do
      {:ok, procedures} -> {:ok, %{procedures: procedures, count: length(procedures)}}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

#### `update_procedure.ex`

```elixir
defmodule Goodwizard.Actions.Memory.Procedural.UpdateProcedure do
  use Jido.Action,
    name: "update_procedure",
    description: "Update an existing procedure's steps, confidence, or other fields",
    schema: [
      id: [type: :string, required: true],
      summary: [type: :string],
      tags: [type: {:list, :string}],
      confidence: [type: {:in, ~w(high medium low)a}],
      when_to_apply: [type: :string],
      steps: [type: :string],
      notes: [type: :string]
    ]

  def run(params, context) do
    memory_dir = resolve_memory_dir(context)
    # Build frontmatter updates from non-nil params
    # Build body from when_to_apply/steps/notes if any provided
    # Call Procedural.update/4
  end
end
```

#### `use_procedure.ex`

```elixir
defmodule Goodwizard.Actions.Memory.Procedural.UseProcedure do
  use Jido.Action,
    name: "use_procedure",
    description: "Mark a procedure as used and record the outcome (adjusts confidence)",
    schema: [
      id: [type: :string, required: true],
      outcome: [type: {:in, ~w(success failure)a}, required: true]
    ]

  def run(params, context) do
    memory_dir = resolve_memory_dir(context)

    case Goodwizard.Memory.Procedural.record_usage(memory_dir, params.id, params.outcome) do
      {:ok, updated} -> {:ok, %{procedure: updated, message: "Procedure usage recorded (#{params.outcome})"}}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

#### `list_procedures.ex`

```elixir
defmodule Goodwizard.Actions.Memory.Procedural.ListProcedures do
  use Jido.Action,
    name: "list_procedures",
    description: "List all learned procedures",
    schema: [
      limit: [type: :integer, default: 20],
      type: [type: :string],
      confidence: [type: :string, doc: "Minimum confidence level"]
    ]

  def run(params, context) do
    memory_dir = resolve_memory_dir(context)
    opts = build_filter_opts(params)

    case Goodwizard.Memory.Procedural.list(memory_dir, opts) do
      {:ok, procedures} -> {:ok, %{procedures: procedures, count: length(procedures)}}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### 2.3 Register Actions as Tools

**File:** `lib/goodwizard/plugins/tools.ex` (or wherever tools are registered)

Add all new actions to the agent's available tool list:

```elixir
# Episodic memory tools
Goodwizard.Actions.Memory.Episodic.RecordEpisode,
Goodwizard.Actions.Memory.Episodic.SearchEpisodes,
Goodwizard.Actions.Memory.Episodic.ReadEpisode,
Goodwizard.Actions.Memory.Episodic.ListEpisodes,

# Procedural memory tools
Goodwizard.Actions.Memory.Procedural.LearnProcedure,
Goodwizard.Actions.Memory.Procedural.RecallProcedures,
Goodwizard.Actions.Memory.Procedural.UpdateProcedure,
Goodwizard.Actions.Memory.Procedural.UseProcedure,
Goodwizard.Actions.Memory.Procedural.ListProcedures,
```

---

## Phase 3: Enhanced Consolidation

### 3.1 Refactor `Consolidate` Action

**File:** `lib/goodwizard/actions/memory/consolidate.ex` (existing, refactor)

The current consolidation extracts a flat `history_entry` and `memory_update`. Enhance it to produce structured output across all three memory types.

**New LLM prompt for consolidation:**

```
Analyze the following conversation segment and extract memories in three categories:

1. EPISODES: Notable events that happened (problems solved, errors encountered, decisions made, tasks completed). Each episode needs: type, summary, tags, outcome, observation, approach, result, lessons.

2. SEMANTIC UPDATES: Facts learned about the user, their preferences, their projects, or the world. Return as updates to the existing memory profile.

3. PROCEDURAL INSIGHTS: Any patterns about HOW to do things effectively. If a successful approach was used that could be reused, capture it as a procedure with: type, summary, tags, when_to_apply, steps, notes.

Current memory profile:
{memory_md_content}

Existing procedures (to avoid duplicates):
{procedure_summaries}

Conversation to analyze:
{messages}

Respond in JSON:
{
  "episodes": [
    {
      "type": "problem_solved",
      "summary": "...",
      "tags": ["..."],
      "outcome": "success",
      "observation": "...",
      "approach": "...",
      "result": "...",
      "lessons": "..."
    }
  ],
  "memory_profile_update": "Updated MEMORY.md content...",
  "procedural_insights": [
    {
      "type": "workflow",
      "summary": "...",
      "tags": ["..."],
      "when_to_apply": "...",
      "steps": "...",
      "notes": "...",
      "updates_existing": null  // or existing procedure ID if refining
    }
  ]
}
```

**Implementation flow:**
1. Gather messages beyond `memory_window` (same as current)
2. Load current MEMORY.md content
3. Load existing procedure summaries (frontmatter only — for dedup)
4. Call Claude Haiku with structured prompt
5. Parse JSON response
6. For each episode: call `Memory.Episodic.create/3`
7. Write updated `MEMORY.md`
8. For each procedural insight:
   - If `updates_existing` is set: call `Memory.Procedural.update/4`
   - Else: call `Memory.Procedural.create/3` with `source: "learned"`
9. Append summary to HISTORY.md (keep as a consolidation log)
10. Return trimmed messages

### 3.2 Keep HISTORY.md as Consolidation Log

HISTORY.md changes from being the primary episodic store to a lightweight consolidation log:

```markdown
## 2026-02-17T10:30:00Z — Consolidation
Extracted 2 episodes, updated memory profile, learned 1 new procedure.
Episodes: "Debugged Jido executor issue" (success), "Failed deploy attempt" (failure)
Procedure: "How to debug Jido action failures"
```

This provides a chronological audit trail without duplicating the structured episodic data.

---

## Phase 4: Context Loading

### 4.1 Create `LoadMemoryContext` Action

**File:** `lib/goodwizard/actions/memory/load_context.ex`

This action runs at conversation start to load relevant memories into the system context.

```elixir
defmodule Goodwizard.Actions.Memory.LoadContext do
  use Jido.Action,
    name: "load_memory_context",
    description: "Load relevant episodic and procedural memories for the current conversation",
    schema: [
      topic: [type: :string, default: "", doc: "Current conversation topic or first message"],
      max_episodes: [type: :integer, default: 5],
      max_procedures: [type: :integer, default: 3]
    ]

  def run(params, context) do
    memory_dir = resolve_memory_dir(context)

    # 1. MEMORY.md is already loaded by memory plugin — skip

    # 2. Load recent episodes (always useful)
    {:ok, recent_episodes} = Memory.Episodic.list(memory_dir, limit: 3)

    # 3. Load topic-relevant episodes (if topic provided)
    topic_episodes = if params.topic != "" do
      {:ok, results} = Memory.Episodic.search(memory_dir, params.topic, limit: params.max_episodes - 3)
      results
    else
      []
    end

    # 4. Deduplicate and merge
    all_episodes = deduplicate_by_id(recent_episodes ++ topic_episodes)
    |> Enum.take(params.max_episodes)

    # 5. Load relevant procedures
    procedures = if params.topic != "" do
      {:ok, results} = Memory.Procedural.recall(memory_dir, params.topic, limit: params.max_procedures)
      results
    else
      {:ok, results} = Memory.Procedural.list(memory_dir, limit: params.max_procedures)
      results
    end

    # 6. Format as context string
    context_text = format_memory_context(all_episodes, procedures)

    {:ok, %{memory_context: context_text, episodes_loaded: length(all_episodes), procedures_loaded: length(procedures)}}
  end

  defp format_memory_context(episodes, procedures) do
    """
    ## Relevant Past Experiences
    #{format_episodes(episodes)}

    ## Relevant Procedures
    #{format_procedures(procedures)}
    """
  end
end
```

### 4.2 Integration Point

Where to call `LoadMemoryContext`:
- **Option A:** In the channel handler (CLI/Telegram) on first message of a session
- **Option B:** As a Jido directive after session restore
- **Option C:** In the memory plugin's mount callback

**Recommended: Option A** — the channel handler already knows when a new conversation starts and has the first message (topic). Call the action there and prepend the result to the system context.

---

## Phase 5: Memory Lifecycle

### 5.1 Episodic Archival

**File:** `lib/goodwizard/actions/memory/episodic/archive_old.ex`

Prevent unbounded growth of episodic memory:

- **Trigger:** When episodic/ contains >200 files
- **Strategy:**
  1. Keep all episodes from last 30 days
  2. Keep all episodes with `outcome: success` from last 90 days
  3. For older episodes: consolidate into monthly summary episodes
  4. Delete individual archived episodes after consolidation
- **Monthly summary format:** One episode per month with aggregated stats and key lessons

### 5.2 Procedural Confidence Decay

**File:** Add to `Memory.Procedural` module

Periodic maintenance (run during consolidation or on a schedule):

```elixir
def decay_unused(memory_dir, days_threshold \\ 60) do
  # Find procedures not used in {days_threshold} days
  # Demote confidence: high→medium, medium→low
  # Procedures at "low" confidence not used in 120 days → archive/delete
end
```

### 5.3 Cross-Type Consolidation

**File:** `lib/goodwizard/actions/memory/cross_consolidate.ex`

Periodic action that looks for patterns across episodes to create new procedures:

```elixir
defmodule Goodwizard.Actions.Memory.CrossConsolidate do
  @moduledoc """
  Analyze recent episodes to identify recurring patterns that should become procedures.
  Run periodically (e.g., after every 10 episodes).
  """

  def run(params, context) do
    memory_dir = resolve_memory_dir(context)

    # 1. Load recent successful episodes (last 20)
    {:ok, episodes} = Memory.Episodic.list(memory_dir, limit: 20, outcome: "success")

    # 2. Load existing procedures (for dedup)
    {:ok, procedures} = Memory.Procedural.list(memory_dir, limit: 100)

    # 3. Call LLM to identify patterns
    # Prompt: "Given these successful episodes and existing procedures,
    #          identify any repeated patterns that should become new procedures.
    #          Only suggest procedures that don't duplicate existing ones."

    # 4. Create new procedures with source: "inferred"
  end
end
```

---

## Testing Strategy

### Unit Tests

**Per module:**

| Module | Test File | Key Tests |
|---|---|---|
| `Memory.Entry` | `test/goodwizard/memory/entry_test.exs` | parse/serialize roundtrip, frontmatter limits, YAML security |
| `Memory.Episodic` | `test/goodwizard/memory/episodic_test.exs` | CRUD, search by tags/type/outcome/text, date filtering, limit |
| `Memory.Procedural` | `test/goodwizard/memory/procedural_test.exs` | CRUD, recall scoring, usage tracking, confidence adjustment |
| `Memory.Paths` | `test/goodwizard/memory/paths_test.exs` | Path construction, validation, traversal prevention |
| `Memory.Seeds` | `test/goodwizard/memory/seeds_test.exs` | Directory creation, idempotency |

**Per action (integration tests):**

| Action | Key Tests |
|---|---|
| RecordEpisode | Creates file, validates frontmatter, generates ID/timestamp |
| SearchEpisodes | Finds by query, filters correctly, respects limit |
| LearnProcedure | Creates file, sets defaults (usage_count=0, confidence) |
| RecallProcedures | Scores and ranks results, handles empty store |
| UseProcedure | Increments count, adjusts confidence, updates timestamps |
| LoadContext | Returns formatted context, handles empty stores |

### Property Tests

Consider `StreamData` for:
- Arbitrary frontmatter → serialize → parse roundtrip
- Search with random filters always returns subset of list results
- Usage tracking monotonically increases usage_count

---

## File Manifest

### New Files

```
lib/goodwizard/memory/
├── entry.ex                              # Shared markdown+YAML parser
├── episodic.ex                           # Episodic memory core module
├── procedural.ex                         # Procedural memory core module
└── seeds.ex                              # Directory bootstrapping

lib/goodwizard/actions/memory/
├── episodic/
│   ├── record_episode.ex                 # Create episode
│   ├── search_episodes.ex                # Search episodes
│   ├── read_episode.ex                   # Read single episode
│   └── list_episodes.ex                  # List episodes
├── procedural/
│   ├── learn_procedure.ex                # Create procedure
│   ├── recall_procedures.ex              # Find relevant procedures
│   ├── update_procedure.ex               # Update procedure
│   ├── use_procedure.ex                  # Track usage + adjust confidence
│   └── list_procedures.ex                # List procedures
├── load_context.ex                       # Load relevant memories into context
└── cross_consolidate.ex                  # Cross-type pattern detection

test/goodwizard/memory/
├── entry_test.exs
├── episodic_test.exs
├── procedural_test.exs
├── paths_test.exs
└── seeds_test.exs

test/goodwizard/actions/memory/
├── episodic/
│   ├── record_episode_test.exs
│   ├── search_episodes_test.exs
│   ├── read_episode_test.exs
│   └── list_episodes_test.exs
├── procedural/
│   ├── learn_procedure_test.exs
│   ├── recall_procedures_test.exs
│   ├── update_procedure_test.exs
│   ├── use_procedure_test.exs
│   └── list_procedures_test.exs
├── load_context_test.exs
└── cross_consolidate_test.exs
```

### Modified Files

```
lib/goodwizard/memory/paths.ex            # Add episodic/procedural path helpers
lib/goodwizard/actions/memory/consolidate.ex  # Enhanced 3-type extraction
lib/goodwizard/character/preamble.ex       # Updated orientation text
lib/goodwizard/plugins/tools.ex            # Register new actions
lib/mix/tasks/goodwizard.setup.ex          # Bootstrap new directories
test/goodwizard/character/preamble_test.exs # Updated assertions
```

### New Directories in Workspace

```
priv/workspace/memory/episodic/            # Episodic memory files
priv/workspace/memory/procedural/          # Procedural memory files
```

---

## Implementation Order

```
Phase 1 (Foundation)          Phase 2 (Actions)              Phase 3 (Consolidation)
┌──────────────────┐          ┌──────────────────┐           ┌──────────────────┐
│ 1.1 Entry module │──────┐   │ 2.1 Episodic     │           │ 3.1 Refactor     │
│ 1.2 Episodic     │──────┤   │     actions (4)   │           │     consolidate  │
│ 1.3 Procedural   │──────┤   │ 2.2 Procedural   │           │ 3.2 Update       │
│ 1.4 Paths update │──┐   │   │     actions (5)   │           │     HISTORY.md   │
│ 1.5 Seeds        │  │   │   │ 2.3 Register     │           │     role         │
│ 1.6 Preamble     │  │   └──▶│     tools        │──────────▶│                  │
└──────────────────┘  │       └──────────────────┘           └──────────────────┘
                      │                                              │
                      │       Phase 4 (Context)              Phase 5 (Lifecycle)
                      │       ┌──────────────────┐           ┌──────────────────┐
                      │       │ 4.1 LoadContext   │           │ 5.1 Archival     │
                      └──────▶│ 4.2 Integration  │──────────▶│ 5.2 Decay        │
                              └──────────────────┘           │ 5.3 Cross-consol │
                                                             └──────────────────┘
```

**Estimated scope per phase:**
- Phase 1: ~6 files, ~400 LOC + tests
- Phase 2: ~10 files, ~500 LOC + tests
- Phase 3: ~1 file refactored, ~200 LOC + tests
- Phase 4: ~1 file, ~100 LOC + tests
- Phase 5: ~2 files, ~200 LOC + tests

Each phase is independently testable and deployable. Phase 1+2 provide immediate value. Phases 3-5 add intelligence over time.
