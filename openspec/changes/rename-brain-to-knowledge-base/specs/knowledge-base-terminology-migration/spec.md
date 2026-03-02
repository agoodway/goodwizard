## ADDED Requirements

### Requirement: Canonical knowledge base terminology
The system SHALL treat "knowledge base" as the canonical product and documentation term for structured long-term knowledge storage. The short alias `kb` MUST be accepted on these explicit external surfaces: CLI/help references, user-supplied config keys, and user-invoked action/interface names. Internal-only surfaces (module names, telemetry keys, and canonical persisted directory names) MUST use canonical naming and MUST NOT rely on `kb` aliases.

#### Scenario: User-facing language uses canonical term
- **WHEN** a user reads generated help text, prompts, or documentation for the feature
- **THEN** the term "knowledge base" is used instead of "brain" and "kb" may be shown as a supported alias

#### Scenario: Alias support excludes internal-only surfaces
- **WHEN** the system persists workspace assets or emits internal telemetry identifiers
- **THEN** it uses canonical names (for example `knowledge_base`) and does not persist or emit internal identifiers using `kb` aliases

### Requirement: Backward-compatible migration period for legacy names
The system SHALL support legacy "brain" references during a migration period by resolving them to knowledge base equivalents while emitting a deprecation signal.

#### Scenario: Legacy command or config key is used
- **WHEN** a user or integration invokes a legacy `brain`-named interface that has a direct `knowledge_base` equivalent
- **THEN** the request succeeds using the equivalent knowledge base behavior and returns a deprecation warning indicating the replacement name

### Requirement: Workspace structure migration
The system SHALL define and enforce migration rules for workspace assets currently rooted at `brain/`, including directory naming, schema location, and reference normalization.

#### Scenario: Existing workspace is initialized under legacy layout
- **WHEN** the system starts against a workspace that contains `brain/` assets
- **THEN** it migrates or maps those assets to the knowledge base layout according to the migration rules without data loss

#### Scenario: Re-running migration is idempotent
- **GIVEN** a workspace that has already been migrated to canonical knowledge base layout
- **WHEN** migration runs again (startup-time or explicit invocation)
- **THEN** the run is a no-op for already canonical assets, creates no duplicate rewrites, and preserves data

### Requirement: Breaking-change enforcement after migration window
After the declared migration window ends, the system SHALL reject unsupported `brain`-named interfaces that were marked deprecated, and MUST provide actionable migration guidance.

#### Scenario: Legacy interface is used after removal
- **WHEN** a caller uses a removed `brain`-named interface after the migration window
- **THEN** the system returns an error that identifies the replacement `knowledge_base` or `kb` interface and the required migration step
