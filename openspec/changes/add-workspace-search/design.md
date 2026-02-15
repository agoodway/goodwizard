## Reference

See [docs/md-search-reference-architecture.md](../../../docs/md-search-reference-architecture.md) for the full reference architecture (module examples, Bumblebee serving setup, Vettore index wrapper, chunking strategy, and performance notes).

## Context

Goodwizard is a Jido-based AI agent with a file-backed workspace (`priv/workspace/`) containing markdown files across `brain/`, `memory/`, `sessions/`, and `skills/` directories. The agent currently has `ReadFile`, `GrepFile`, and `SearchHistory` actions for locating content, but all rely on exact paths or string matching. There is no semantic retrieval.

The workspace is modest in size (tens to low hundreds of `.md` files). Content changes infrequently within a session but may change between sessions. The supervision tree follows a `rest_for_one` strategy: Config → Cache → Jido → Messaging → optional channels.

## Goals / Non-Goals

**Goals:**
- Enable the agent to semantically search workspace markdown by meaning, not just string match
- Run entirely locally — no external API calls for embeddings
- Configurable directory exclusions so transient data (sessions, skills) can be skipped
- Async indexing at startup so search doesn't block agent boot
- Expose search as a Jido action (tool) the agent can call during conversation

**Non-Goals:**
- Persistent vector storage across restarts (rebuild from source files each boot)
- Real-time incremental re-indexing when files change mid-session
- Full-text search or hybrid retrieval (semantic only for v1)
- Support for non-markdown file types
- GPU acceleration (CPU-only for v1; EXLA compiles for CPU by default)

## Decisions

### 1. Embedding model: `nomic-ai/nomic-embed-text-v1` via Bumblebee

**Choice**: Use a BERT-based text embedding model loaded through Bumblebee's `TextEmbedding` serving.

**Why**: Bumblebee already has working support for BERT-architecture models via `Bumblebee.Text.Bert`. Nomic Embed v1 is a well-regarded embedding model (768-dim, 512-token context). Runs locally on CPU with EXLA, no API keys needed. Jina v2 is an alternative but Nomic has better community benchmarks for retrieval tasks.

**Alternative considered**: Calling an external embedding API (OpenAI, Voyage). Rejected — adds latency, cost, and an external dependency for a feature that only needs to handle hundreds of chunks.

### 2. Vector store: Vettore (in-memory, Rust NIF)

**Choice**: Use Vettore's in-memory cosine similarity search with a single collection.

**Why**: Vettore is lightweight, Rust-backed via Rustler, and designed for exactly this use case — small to medium in-memory vector collections. No external processes or servers. The workspace corpus fits comfortably in memory.

**Alternative considered**: ETS-based brute-force search or pgvector. ETS would require implementing distance functions ourselves. pgvector adds a Postgres dependency. Both are overkill for <10k vectors.

### 3. Chunking strategy: heading-based with max-char fallback

**Choice**: Split markdown on heading boundaries (`## `, `### `, etc.), then split oversized chunks at character boundaries. Each chunk carries its source file path and chunk index as metadata.

**Why**: Heading-based splitting preserves semantic boundaries in markdown. The max-char fallback (1500 chars) prevents embedding model overflow (512 tokens ≈ ~2000 chars). Simple, no external tokenizer needed.

**Alternative considered**: Token-based chunking with the model's tokenizer. More precise but adds complexity. Heading-based is good enough for v1 and matches how humans organize markdown.

### 4. Architecture: GenServer pair under the supervision tree

**Choice**: Two GenServers — `Search.Embedder` (holds the Nx.Serving) and `Search.Index` (holds the Vettore collection). Pure-function modules for `Files` and `Chunker`. A `Search` facade module for the public API. Two Jido actions (`IndexWorkspace`, `QueryWorkspace`) registered on the agent.

**Why**: Follows the existing Goodwizard pattern (GenServers for stateful processes, pure modules for transforms, actions for agent-callable tools). The embedder must be long-lived to avoid reloading the model. The index must be long-lived to persist vectors across queries.

### 5. Supervision placement: after Cache, before Jido

**Choice**: Insert `Search.Embedder` and `Search.Index` into the children list between `Goodwizard.Cache` and `Goodwizard.Jido`. Indexing runs as an async Task after both are alive.

**Why**: The `rest_for_one` strategy means if Cache restarts, Search restarts too (correct — search depends on config via Cache). Jido starts after Search, so the agent's tools are available once the agent boots. Indexing is async so it doesn't block the supervision tree.

### 6. Configuration via `[search]` TOML section

**Choice**: Add a `[search]` section to `config.toml` with keys: `exclude_dirs` (list of strings, default `["sessions", "skills"]`), `model` (string, default `"nomic-ai/nomic-embed-text-v1"`), `batch_size` (integer, default 8), `max_chunk_chars` (integer, default 1500), `top_k` (integer, default 5).

**Why**: Follows the existing config pattern. Exclude dirs are the most important knob — users will want to skip `sessions/` (large, transient) and `skills/` (code, not knowledge) but include `brain/` and `memory/`. All values have sensible defaults so the `[search]` section is optional.

## Risks / Trade-offs

- **[Cold start latency]** → Model download (~130 MB) on first boot, ~5-10s load time on subsequent boots. Mitigation: indexing is async; agent can respond before indexing completes. Document the first-boot download.

- **[Memory usage]** → Nx model weights (~250 MB) + Vettore vectors (~1 MB for 1000 chunks) live in memory. Mitigation: acceptable for a single-user agent. Non-goal to optimize for constrained environments in v1.

- **[No persistence]** → Vectors are rebuilt every boot. Mitigation: for a typical workspace, full re-index takes <30s on CPU. Acceptable trade-off vs. complexity of serialization and cache invalidation. Can add persistence in a future iteration.

- **[EXLA build dependency]** → EXLA requires a C compiler and may have platform-specific issues. Mitigation: Elixir/Nx ecosystem handles this well on macOS/Linux. Document any special build steps.

- **[Stale index]** → Files modified during a session won't be reflected in search results. Mitigation: the `IndexWorkspace` action lets the agent manually re-index. Automatic re-indexing is a non-goal for v1.

## Module Map

```
lib/goodwizard/search/
├── files.ex          # File discovery with exclude-dir filtering
├── chunker.ex        # Heading-based markdown chunking
├── embedder.ex       # GenServer wrapping Bumblebee TextEmbedding serving
└── index.ex          # GenServer wrapping Vettore collection

lib/goodwizard/search.ex  # Public facade (index_workspace/1, query/2)

lib/goodwizard/actions/search/
├── index_workspace.ex    # Jido action: trigger workspace indexing
└── query_workspace.ex    # Jido action: semantic search query
```
