## ADDED Requirements

### Requirement: File discovery with configurable exclusions
The system SHALL discover all `.md` files under the workspace root recursively. The system SHALL exclude files within directories listed in the `[search] exclude_dirs` configuration. The default exclusion list SHALL be `["sessions", "skills"]`. Exclusion matching SHALL be based on the relative path from the workspace root — a directory name anywhere in the path triggers exclusion.

#### Scenario: Discover markdown files in workspace
- **WHEN** the search subsystem scans the workspace at `priv/workspace/`
- **THEN** it returns paths for all `.md` files under `brain/`, `memory/`, and any other non-excluded directories

#### Scenario: Exclude configured directories
- **WHEN** `exclude_dirs` is configured as `["sessions", "skills"]`
- **THEN** no files under `workspace/sessions/` or `workspace/skills/` appear in the discovered file list

#### Scenario: Custom exclusion list
- **WHEN** `exclude_dirs` is configured as `["sessions", "skills", "archive"]`
- **THEN** files under `workspace/archive/` are also excluded from discovery

#### Scenario: Empty exclusion list
- **WHEN** `exclude_dirs` is configured as `[]`
- **THEN** all `.md` files under the workspace root are discovered, including those in `sessions/` and `skills/`

### Requirement: Heading-based markdown chunking
The system SHALL split markdown content into chunks at heading boundaries (`#`, `##`, `###`, etc.). Each chunk SHALL contain the heading and all content until the next heading of equal or higher level. Chunks exceeding `max_chunk_chars` (default 1500) SHALL be split at character boundaries. Each chunk SHALL carry metadata: source file path, relative path from workspace root, and chunk index.

#### Scenario: Split on headings
- **WHEN** a markdown file contains three `##` sections
- **THEN** the chunker produces three chunks, each starting with its heading

#### Scenario: Large chunk overflow
- **WHEN** a single section exceeds `max_chunk_chars`
- **THEN** it is split into multiple chunks, each at most `max_chunk_chars` characters

#### Scenario: File with no headings
- **WHEN** a markdown file has no heading markers
- **THEN** the entire file content becomes a single chunk (or multiple if it exceeds `max_chunk_chars`)

### Requirement: Text embedding via local model
The system SHALL embed text chunks into vector representations using a Bumblebee-loaded BERT-based model. The default model SHALL be `nomic-ai/nomic-embed-text-v1`. The embedding model SHALL be configurable via `[search] model` in config. The system SHALL support batch embedding for efficiency. Embeddings SHALL be plain Elixir float lists suitable for Vettore insertion.

#### Scenario: Embed a batch of chunks
- **WHEN** 8 text chunks are submitted for embedding
- **THEN** the embedder returns 8 float-list vectors, each of the model's output dimension

#### Scenario: Embed a single query string
- **WHEN** a single query string is submitted for embedding
- **THEN** the embedder returns one float-list vector

#### Scenario: Model loads at startup
- **WHEN** the application starts
- **THEN** the embedder GenServer loads the configured model and tokenizer, and is ready to accept embedding requests

### Requirement: In-memory vector index
The system SHALL store chunk embeddings in a Vettore in-memory collection. Each entry SHALL include the embedding vector, a string ID (`"<relative-path>:<chunk-index>"`), and metadata containing the absolute file path, relative path, and chunk span info. The system SHALL support cosine similarity search returning the top-k most similar entries.

#### Scenario: Add chunks to index
- **WHEN** embeddings for 10 chunks from `brain/people/alice.md` are added
- **THEN** the index contains 10 entries with IDs like `"brain/people/alice.md:0"` through `"brain/people/alice.md:9"`

#### Scenario: Search by query embedding
- **WHEN** a query embedding is submitted with k=5
- **THEN** the index returns up to 5 results sorted by cosine similarity, each including the ID, score, and metadata

#### Scenario: Empty index search
- **WHEN** a search is performed before any indexing has occurred
- **THEN** the index returns an empty list

### Requirement: Workspace indexing action
The system SHALL provide a Jido action `Goodwizard.Actions.Search.IndexWorkspace` that triggers full workspace indexing. The action SHALL discover files, chunk them, embed the chunks in batches, and insert all embeddings into the vector index. The action SHALL accept an optional `workspace` parameter, falling back to the configured workspace path. The action SHALL clear the existing index before re-indexing.

#### Scenario: Index workspace on demand
- **WHEN** the agent calls the `index_workspace` action
- **THEN** all non-excluded `.md` files are discovered, chunked, embedded, and stored in the vector index
- **AND** the action returns a summary with file count and chunk count

#### Scenario: Re-index clears stale data
- **WHEN** the agent calls `index_workspace` after files have been deleted from the workspace
- **THEN** the previous index is cleared and only current files are indexed

### Requirement: Semantic query action
The system SHALL provide a Jido action `Goodwizard.Actions.Search.QueryWorkspace` that performs semantic search. The action SHALL accept a `query` string and optional `top_k` parameter (default from config, fallback 5). The action SHALL embed the query, search the vector index, and return results with file paths, relevance scores, and the content of matching chunks re-read from disk.

#### Scenario: Query returns relevant results
- **WHEN** the agent queries "What do I know about Alice's birthday?"
- **THEN** the action returns results ranked by semantic similarity, each containing the file path, relative path, score, and chunk content

#### Scenario: Query with custom top_k
- **WHEN** the agent queries with `top_k: 3`
- **THEN** at most 3 results are returned

#### Scenario: Query against empty index
- **WHEN** the agent queries before indexing has completed
- **THEN** the action returns an empty results list with no error

### Requirement: Search configuration
The system SHALL read search configuration from a `[search]` section in `config.toml`. The following keys SHALL be supported with defaults: `exclude_dirs` (default `["sessions", "skills"]`), `model` (default `"nomic-ai/nomic-embed-text-v1"`), `batch_size` (default 8), `max_chunk_chars` (default 1500), `top_k` (default 5). All keys SHALL be optional — the feature works with defaults if the `[search]` section is omitted.

#### Scenario: Default configuration
- **WHEN** no `[search]` section exists in `config.toml`
- **THEN** the search subsystem uses all default values

#### Scenario: Custom exclude dirs
- **WHEN** the config contains `[search]` with `exclude_dirs = ["sessions", "skills", "drafts"]`
- **THEN** the file discovery module excludes all three directories

### Requirement: Async indexing at startup
The system SHALL trigger workspace indexing asynchronously after the search subsystem processes are alive. Indexing SHALL NOT block the supervision tree or delay agent availability. The agent SHALL be usable before indexing completes — queries against an empty index return empty results.

#### Scenario: Agent available before indexing completes
- **WHEN** the application starts
- **THEN** the agent can receive and respond to messages before workspace indexing finishes

#### Scenario: Indexing completes in background
- **WHEN** the application starts and the workspace contains 50 markdown files
- **THEN** indexing runs asynchronously and the index becomes queryable once complete

### Requirement: Agent tool registration
The system SHALL register `Goodwizard.Actions.Search.IndexWorkspace` and `Goodwizard.Actions.Search.QueryWorkspace` in the agent's tool list. The agent SHALL be able to call these tools during conversation turns.

#### Scenario: Agent uses query tool
- **WHEN** the agent decides it needs context about a topic during conversation
- **THEN** it can invoke the `query_workspace` tool with a natural language query and receive ranked results
