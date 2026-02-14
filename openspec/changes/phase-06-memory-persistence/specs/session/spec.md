## MODIFIED Requirements

### Requirement: Session skill state initialization
`Goodwizard.Skills.Session` SHALL be a Jido Skill with `state_key: :session` that initializes with an empty messages list, a `created_at` timestamp, and an empty metadata map when mounted. If a persisted JSONL session file exists for the agent's session key, it SHALL load messages from that file instead.

#### Scenario: Mount initializes session state
- **WHEN** the Session skill is mounted on an agent via `mount/2` and no persisted session exists
- **THEN** the agent's state at key `:session` contains `%{messages: [], created_at: <iso8601_string>, metadata: %{}}`

#### Scenario: Mount loads persisted session
- **WHEN** the Session skill is mounted and a JSONL file exists at `~/.goodwizard/sessions/<session_key>.jsonl`
- **THEN** the agent's state at key `:session` contains messages loaded from the JSONL file
- **THEN** the `created_at` and `metadata` values are restored from the JSONL metadata line

## ADDED Requirements

### Requirement: Save session to JSONL file
The `save_session/3` function SHALL persist the session state to a JSONL file in the sessions directory. The first line SHALL be a JSON object with session metadata (key, created_at, version). Each subsequent line SHALL be a JSON object representing one message.

#### Scenario: Save session with messages
- **WHEN** `save_session(sessions_dir, session_key, session_state)` is called with a session containing 3 messages
- **THEN** a file at `<sessions_dir>/<session_key>.jsonl` is created with 4 lines (1 metadata + 3 messages)

#### Scenario: Session key colons replaced in filename
- **WHEN** the session key is `"cli:direct"`
- **THEN** the filename is `cli_direct.jsonl`

#### Scenario: Save overwrites existing session file
- **WHEN** a session file already exists and `save_session/3` is called
- **THEN** the existing file is replaced with the current session state

### Requirement: Load session from JSONL file
The `load_session/2` function SHALL read a JSONL file and return the session state with metadata and messages restored.

#### Scenario: Load existing session
- **WHEN** `load_session(sessions_dir, session_key)` is called and the JSONL file exists
- **THEN** it returns `{:ok, %{messages: [...], created_at: "...", metadata: %{...}}}`

#### Scenario: Load missing session
- **WHEN** `load_session/2` is called and no JSONL file exists for the session key
- **THEN** it returns `{:error, :not_found}`

#### Scenario: JSONL metadata line parsed correctly
- **WHEN** a session file's first line is `{"key":"cli_direct","created_at":"2026-01-15T10:00:00Z","version":1}`
- **THEN** the loaded session's `created_at` is `"2026-01-15T10:00:00Z"`

#### Scenario: JSONL message lines parsed correctly
- **WHEN** a session file has message lines like `{"role":"user","content":"Hello","timestamp":"2026-01-15T10:00:01Z"}`
- **THEN** each message is restored as a map with `:role`, `:content`, and `:timestamp` keys

### Requirement: Sessions directory created on first save
The sessions directory (`~/.goodwizard/sessions/`) SHALL be created automatically if it does not exist when `save_session/3` is called.

#### Scenario: Directory created automatically
- **WHEN** `save_session/3` is called and `~/.goodwizard/sessions/` does not exist
- **THEN** the directory is created and the session file is written successfully
