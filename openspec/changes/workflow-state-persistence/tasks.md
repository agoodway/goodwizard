## 1. Token Generation

- [ ] 1.1 Create `lib/goodwizard/workflow/state.ex` with `generate_token/0` using `:crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)`

## 2. State Serialization

- [ ] 2.1 Define the state map structure: `token`, `completed_outputs`, `remaining_steps`, `approval_context`, `pipeline_metadata`, `created_at`, `version`
- [ ] 2.2 Implement `serialize/1` (private) to convert state map to Jason-encodable format (handle Step/Pipeline structs)
- [ ] 2.3 Implement `deserialize/1` (private) to reconstruct state map from decoded JSON

## 3. File I/O

- [ ] 3.1 Implement `save/2`: accept token and state map, create `workspace/workflow/state/` directory if needed, write `<token>.json`
- [ ] 3.2 Implement `load/1`: read and decode `<token>.json`, return `{:ok, state}` or `{:error, :not_found}` / `{:error, :corrupt_state}`
- [ ] 3.3 Implement `delete/1`: remove `<token>.json`, return `:ok` even if file doesn't exist
- [ ] 3.4 Add path traversal protection on token input (reject `..`, `/`, null bytes)

## 4. Cache Integration

- [ ] 4.1 In `save/2`, also write to `Goodwizard.Cache` with key `"workflow:state:<token>"`
- [ ] 4.2 In `load/1`, check cache first; on miss read from disk and populate cache
- [ ] 4.3 In `delete/1`, also remove from cache
- [ ] 4.4 Set cache TTL to match state TTL config

## 5. TTL Cleanup

- [ ] 5.1 Implement `cleanup/1`: accept TTL in seconds, list all files in state directory, parse `created_at`, delete expired files
- [ ] 5.2 Delete malformed files (invalid JSON, missing `created_at`) during cleanup
- [ ] 5.3 Log warnings for malformed files before deleting

## 6. Tests

- [ ] 6.1 Tests for token generation: URL-safe format, uniqueness
- [ ] 6.2 Tests for save/load round-trip: write then read back
- [ ] 6.3 Tests for delete: existing token, non-existent token
- [ ] 6.4 Tests for cache integration: cache hit, cache miss fallthrough
- [ ] 6.5 Tests for cleanup: expired files removed, non-expired preserved, malformed removed
- [ ] 6.6 Tests for error cases: corrupt JSON, path traversal in token
