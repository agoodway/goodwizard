## 1. Dependencies and Configuration

- [ ] 1.1 Add `vettore`, `nx`, `exla`, and `bumblebee` dependencies to `mix.exs`
- [ ] 1.2 Add `config :nx, default_backend: EXLA.Backend` to `config/config.exs`
- [ ] 1.3 Add `[search]` defaults to `Goodwizard.Config` (`exclude_dirs`, `model`, `batch_size`, `max_chunk_chars`, `top_k`)
- [ ] 1.4 Add `search_config/0` convenience function to `Goodwizard.Config` that returns the merged search config map

## 2. File Discovery

- [ ] 2.1 Create `lib/goodwizard/search/files.ex` with `list_md_files/2` that discovers `.md` files and filters by exclude dirs
- [ ] 2.2 Add tests for file discovery including exclusion filtering and empty exclusion list

## 3. Markdown Chunker

- [ ] 3.1 Create `lib/goodwizard/search/chunker.ex` with heading-based chunking and max-char overflow splitting
- [ ] 3.2 Add tests for chunking: heading splits, large chunk overflow, no-heading files, metadata on chunks

## 4. Embedding Server

- [ ] 4.1 Create `lib/goodwizard/search/embedder.ex` GenServer that loads the Bumblebee model/tokenizer on init and exposes `embed/1`
- [ ] 4.2 Add tests for embedder (mock or lightweight integration test verifying vector output shape)

## 5. Vector Index

- [ ] 5.1 Create `lib/goodwizard/search/index.ex` GenServer wrapping Vettore collection with `add_chunk/1`, `search/2`, and `clear/0`
- [ ] 5.2 Add tests for index: add chunks, search by embedding, empty index search, clear and re-add

## 6. Search Facade

- [ ] 6.1 Create `lib/goodwizard/search.ex` facade with `index_workspace/1` (discover → chunk → embed → store) and `query/2` (embed query → search → hydrate content from disk)
- [ ] 6.2 Add tests for the facade module end-to-end flow

## 7. Jido Actions

- [ ] 7.1 Create `lib/goodwizard/actions/search/index_workspace.ex` action with optional `workspace` param, calls `Search.index_workspace/1`
- [ ] 7.2 Create `lib/goodwizard/actions/search/query_workspace.ex` action with `query` and optional `top_k` params, calls `Search.query/2`
- [ ] 7.3 Add tests for both actions

## 8. Supervision and Agent Integration

- [ ] 8.1 Add `Search.Embedder` and `Search.Index` to supervision tree in `application.ex` (after Cache, before Jido)
- [ ] 8.2 Add async indexing Task to supervision tree that runs `Search.index_workspace/0` after search processes are alive
- [ ] 8.3 Register `IndexWorkspace` and `QueryWorkspace` in the agent's tool list in `agent.ex`
- [ ] 8.4 Run full `mix check` to verify compilation, formatting, credo, and tests pass
