## Why

The agent can read individual files and grep for exact string matches, but has no way to semantically search across the workspace's markdown knowledge base. When the agent needs to find relevant context — past notes, brain entities, memory entries — it must know the exact file path or search term. A vector-based semantic search over workspace `.md` files would let the agent retrieve relevant content by meaning, dramatically improving context recall for multi-turn conversations and knowledge-heavy tasks.

## What Changes

- Add Bumblebee, EXLA, Nx, and Vettore as dependencies for local text embedding and in-memory vector search
- Add a `Goodwizard.Search` subsystem with modules for file discovery, chunking, embedding, and vector indexing
- Add `Goodwizard.Search.Embedder` GenServer that loads a BERT-based text embedding model via Bumblebee at startup
- Add `Goodwizard.Search.Index` GenServer wrapping a Vettore collection for vector storage and cosine similarity search
- Add `Goodwizard.Search.Files` module for discovering `.md` files with configurable directory exclusions (default: `sessions/`, `skills/`)
- Add `Goodwizard.Search.Chunker` module that splits markdown content by headings into embeddable chunks
- Add `Goodwizard.Actions.Search.IndexWorkspace` action to trigger (re)indexing of workspace markdown
- Add `Goodwizard.Actions.Search.QueryWorkspace` action so the agent can perform semantic queries
- Register both actions as tools on the agent
- Add search processes to the supervision tree (after Cache, before Jido)
- Add `[search]` config section to `config.toml` for exclude dirs, embedding model, batch size

## Capabilities

### New Capabilities
- `workspace-search`: Semantic vector search over workspace markdown files — covers file discovery, chunking, embedding, indexing, querying, and the agent actions that expose the feature

### Modified Capabilities
_None — this is a new, additive capability with no changes to existing specs._

## Impact

- **Dependencies**: Adds `bumblebee`, `nx`, `exla`, and `vettore` to `mix.exs`. EXLA is a native extension and requires a C compiler at build time. First boot downloads the embedding model (~130 MB).
- **Startup time**: Embedding model load adds ~5–10s to cold start. Workspace indexing runs asynchronously after boot.
- **Memory**: Vettore collection and Nx model weights live in-memory. For a typical workspace (~100 files), expect ~50–100 MB additional RAM.
- **Code**: New files under `lib/goodwizard/search/` and `lib/goodwizard/actions/search/`. Supervision tree in `application.ex` gains two children. Agent module gains two tool registrations.
- **Config**: New optional `[search]` section in `config.toml`. Feature works with sensible defaults if section is omitted.
