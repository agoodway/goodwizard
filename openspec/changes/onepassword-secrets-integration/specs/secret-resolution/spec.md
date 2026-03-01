## ADDED Requirements

### Requirement: Secret reference detection

The system SHALL identify string values prefixed with `op://` as 1Password secret references. Non-string values and strings without the `op://` prefix SHALL be treated as literal values and passed through unchanged.

#### Scenario: op:// string detected as secret reference
- **WHEN** a string value starting with `op://` is encountered (e.g., `"op://Vault/Item/Field"`)
- **THEN** the system SHALL classify it as a secret reference requiring resolution

#### Scenario: Plain string is not a secret reference
- **WHEN** a string value without the `op://` prefix is encountered (e.g., `"sk-ant-api03-abc"`)
- **THEN** the system SHALL treat it as a literal value and return it unchanged

#### Scenario: Non-string values are not secret references
- **WHEN** a non-string value is encountered (integer, boolean, nil, list)
- **THEN** the system SHALL treat it as a literal value and return it unchanged

### Requirement: Single secret resolution via op CLI

The system SHALL resolve an `op://` secret reference by executing `op read --no-newline <uri>` and returning the trimmed output on success (exit code 0).

#### Scenario: Successful resolution
- **WHEN** `op read --no-newline "op://Vault/Item/Field"` exits with code 0 and outputs `"my-secret"`
- **THEN** the system SHALL return the string `"my-secret"` with trailing whitespace trimmed

#### Scenario: op CLI not found on PATH
- **WHEN** the `op` binary is not found via `System.find_executable("op")`
- **THEN** the system SHALL log a warning with the redacted URI and return the literal `op://` string unchanged

#### Scenario: op CLI returns non-zero exit code
- **WHEN** `op read` exits with a non-zero code (e.g., not signed in, vault locked, item not found)
- **THEN** the system SHALL log a warning including the exit code and trimmed stderr, and return the literal `op://` string unchanged

#### Scenario: op CLI raises or times out
- **WHEN** the `op read` command raises an exception or times out
- **THEN** the system SHALL log a warning and return the literal `op://` string unchanged

### Requirement: Nested map resolution

The system SHALL walk a nested map structure and resolve all string values that are `op://` secret references, preserving map structure, non-string values, and list elements.

#### Scenario: Config map with nested op:// values
- **WHEN** a map `%{"browser" => %{"search" => %{"brave_api_key" => "op://V/brave/key"}}, "agent" => %{"model" => "anthropic:claude-sonnet-4-5"}}` is resolved
- **THEN** the `brave_api_key` value SHALL be resolved via `op read` and the `model` value SHALL remain unchanged

#### Scenario: Empty map
- **WHEN** an empty map `%{}` is resolved
- **THEN** the system SHALL return `%{}` unchanged

#### Scenario: List values containing op:// strings
- **WHEN** a map contains a list with `op://` string elements
- **THEN** each `op://` string in the list SHALL be resolved individually

### Requirement: Config boot-time resolution

The system SHALL resolve all `op://` values in the config map during `Config.init/1`, after the three-layer merge (defaults → TOML → env vars) and before numeric validation and browser config wiring. Cache SHALL NOT be used during boot-time resolution (Cache is not started yet).

#### Scenario: TOML file contains op:// values
- **WHEN** `config.toml` contains `brave_api_key = "op://Vault/brave/key"` and Config starts
- **THEN** `Config.get(["browser", "search", "brave_api_key"])` SHALL return the resolved plaintext value

#### Scenario: Env var override contains op:// value
- **WHEN** env var `BRAVE_API_KEY` is set to `"op://Vault/brave/key"` and Config starts
- **THEN** the env var override SHALL be applied first (as a literal), then the entire config map SHALL be resolved, resulting in the plaintext value at `["browser", "search", "brave_api_key"]`

### Requirement: Application env var resolution

The system SHALL check Dotenvy-loaded env vars and Application config for `op://` prefixes during `Config.init/1` and resolve them. Specifically:

- `Application.get_env(:telegex, :token)` — if `op://`, resolve and `Application.put_env`
- `System.get_env("ANTHROPIC_API_KEY")` — if `op://`, resolve and `System.put_env` + `Application.put_env(:req_llm, :anthropic_api_key, ...)`
- `System.get_env("OPENAI_API_KEY")` — if `op://`, resolve and `System.put_env` + `Application.put_env(:req_llm, :openai_api_key, ...)`

#### Scenario: Telegram token is an op:// reference
- **WHEN** `.env` contains `TELEGRAM_BOT_TOKEN=op://Vault/telegram/token` and Config starts
- **THEN** `Application.get_env(:telegex, :token)` SHALL return the resolved plaintext value after Config.init completes

#### Scenario: LLM API key is an op:// reference
- **WHEN** `.env` contains `ANTHROPIC_API_KEY=op://Vault/anthropic/credential` and Config starts
- **THEN** `System.get_env("ANTHROPIC_API_KEY")` SHALL return the resolved plaintext value after Config.init completes

#### Scenario: Env var is already plaintext
- **WHEN** `.env` contains `ANTHROPIC_API_KEY=sk-ant-api03-real-key`
- **THEN** the system SHALL leave the value unchanged

### Requirement: Resolved secret caching

The system SHALL cache resolved secrets in `Goodwizard.Cache` with a configurable TTL when the cache process is available. When the cache is not available (e.g., during boot), caching SHALL be silently skipped.

#### Scenario: Cache available post-boot
- **WHEN** `Secrets.resolve/2` is called after Cache has started and the URI has not been cached
- **THEN** the resolved value SHALL be stored in Cache with key `"secrets:<uri>"` and the configured TTL

#### Scenario: Cache hit
- **WHEN** `Secrets.resolve/2` is called and the URI is already cached
- **THEN** the cached value SHALL be returned without shelling out to `op read`

#### Scenario: Cache not started (boot-time)
- **WHEN** `Secrets.resolve/2` is called before Cache has started (during Config.init)
- **THEN** caching SHALL be skipped and `op read` SHALL be called directly

### Requirement: Secret cache TTL configuration

The system SHALL support a `[secrets]` section in `config.toml` with a `cache_ttl_minutes` option (default: 30). This SHALL be reflected in `@defaults`, `config.toml`, and the setup task template.

#### Scenario: Default cache TTL
- **WHEN** no `[secrets]` section exists in `config.toml`
- **THEN** the cache TTL SHALL default to 30 minutes

#### Scenario: Custom cache TTL
- **WHEN** `config.toml` contains `[secrets]` with `cache_ttl_minutes = 10`
- **THEN** resolved secrets SHALL be cached with a 10-minute TTL

### Requirement: URI redaction in logs

The system SHALL redact secret reference URIs in log messages, showing the vault and item names but replacing the field with `***`.

#### Scenario: Log message for failed resolution
- **WHEN** resolution of `op://MyVault/MyItem/password` fails
- **THEN** the log message SHALL contain `op://MyVault/MyItem/***` and SHALL NOT contain `password`

### Requirement: Test injection via runner option

The `resolve/2` function SHALL accept a `:runner` option that replaces the default `System.cmd/3` call, enabling tests to inject mock behavior without global mocks.

#### Scenario: Mock runner returns success
- **WHEN** `resolve("op://V/I/F", runner: fn "op", ["read", "--no-newline", _], _ -> {"secret", 0} end)` is called
- **THEN** the function SHALL return `"secret"` without calling the real `op` CLI

#### Scenario: Mock runner returns failure
- **WHEN** `resolve("op://V/I/F", runner: fn "op", _, _ -> {"error", 1} end)` is called
- **THEN** the function SHALL return the literal `"op://V/I/F"` and log a warning

### Requirement: op CLI availability check

The system SHALL provide a function to check whether the `op` CLI binary is available on PATH, returning a boolean.

#### Scenario: op CLI installed
- **WHEN** `System.find_executable("op")` returns a path
- **THEN** `available?/0` SHALL return `true`

#### Scenario: op CLI not installed
- **WHEN** `System.find_executable("op")` returns `nil`
- **THEN** `available?/0` SHALL return `false`
