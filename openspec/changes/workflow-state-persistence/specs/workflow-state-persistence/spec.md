## ADDED Requirements

### Requirement: Resume tokens are URL-safe random strings

The `Goodwizard.Workflow.State` module SHALL provide a `generate_token/0` function that returns a URL-safe random string generated via `:crypto.strong_rand_bytes/1` and `Base.url_encode64/2`.

#### Scenario: Generated token is URL-safe

- **WHEN** `generate_token/0` is called
- **THEN** it returns a string matching `~r/^[A-Za-z0-9_-]+$/`

#### Scenario: Generated tokens are unique

- **WHEN** `generate_token/0` is called 1000 times
- **THEN** all returned tokens are distinct

### Requirement: Halted workflow state is saved to disk

The module SHALL provide a `save/2` function that accepts a token and a state map, serializes it as JSON, and writes it to `workspace/workflow/state/<token>.json`. The directory SHALL be created if it does not exist.

#### Scenario: State is saved as a JSON file

- **WHEN** `save("abc123", state_map)` is called
- **THEN** a file at `workspace/workflow/state/abc123.json` exists containing valid JSON with the state data

#### Scenario: State includes required fields

- **WHEN** state is saved
- **THEN** the JSON file contains `token`, `completed_outputs`, `remaining_steps`, `approval_context`, `pipeline_metadata`, `created_at`, and `version` fields

#### Scenario: Save creates directory if missing

- **WHEN** `save/2` is called and the `workflow/state/` directory does not exist
- **THEN** the directory is created and the file is written successfully

### Requirement: Halted workflow state is loaded by token

The module SHALL provide a `load/1` function that accepts a token, reads and decodes the corresponding JSON file, and returns `{:ok, state_map}` or `{:error, :not_found}`.

#### Scenario: Existing state is loaded

- **WHEN** `load("abc123")` is called and the file exists
- **THEN** it returns `{:ok, state_map}` with the deserialized state

#### Scenario: Missing token returns error

- **WHEN** `load("nonexistent")` is called
- **THEN** it returns `{:error, :not_found}`

#### Scenario: Corrupted file returns error

- **WHEN** `load/1` is called for a file containing invalid JSON
- **THEN** it returns `{:error, :corrupt_state}`

### Requirement: State is cached for fast access

The module SHALL use `Goodwizard.Cache` for read-through caching. `load/1` SHALL check cache first. `save/2` SHALL write to both cache and disk. `delete/1` SHALL remove from both.

#### Scenario: Cache hit avoids disk read

- **WHEN** state was recently saved and `load/1` is called
- **THEN** the state is returned from cache without reading the file

#### Scenario: Cache miss falls through to disk

- **WHEN** cache does not contain the token (e.g., after restart) and the file exists
- **THEN** `load/1` reads from disk and populates the cache

### Requirement: State can be deleted

The module SHALL provide a `delete/1` function that removes both the disk file and the cache entry for a given token.

#### Scenario: Delete removes file and cache entry

- **WHEN** `delete("abc123")` is called
- **THEN** the file at `workspace/workflow/state/abc123.json` no longer exists and the cache entry is removed

#### Scenario: Delete of non-existent token succeeds

- **WHEN** `delete("nonexistent")` is called
- **THEN** it returns `:ok` without error

### Requirement: Expired state files are cleaned up by TTL

The module SHALL provide a `cleanup/1` function that accepts a TTL in seconds and removes all state files whose `created_at` timestamp is older than the TTL.

#### Scenario: Expired files are removed

- **WHEN** `cleanup(3600)` is called and a state file has `created_at` older than 1 hour
- **THEN** the file is deleted

#### Scenario: Non-expired files are preserved

- **WHEN** `cleanup(3600)` is called and a state file has `created_at` within the last hour
- **THEN** the file is not deleted

#### Scenario: Malformed files are removed during cleanup

- **WHEN** `cleanup/1` encounters a file with invalid JSON or missing `created_at`
- **THEN** the file is deleted
