### Requirement: Inline query execution

The system SHALL accept a query string via the Mix task and execute it against a fully initialized Goodwizard agent.

#### Scenario: Run inline query
- **WHEN** `mix goodwizard.scenario run "Hello, who are you?"` is executed
- **THEN** the system SHALL start the application, create an agent with a temp workspace, send the query, and print a structured result containing the response text, tool calls, timing, and log entries

#### Scenario: Run with custom timeout
- **WHEN** `mix goodwizard.scenario run "complex query" --timeout 300000` is executed
- **THEN** the system SHALL use the specified timeout (300s) instead of the default (120s) for the `ask_sync` call

#### Scenario: Run with real workspace
- **WHEN** `mix goodwizard.scenario run "query" --workspace /path/to/workspace` is executed
- **THEN** the system SHALL use the specified workspace instead of creating a temp one

### Requirement: File-based scenario execution

The system SHALL load and execute TOML scenario files from `priv/scenarios/`.

#### Scenario: Run named scenario
- **WHEN** `mix goodwizard.scenario run smoke_test` is executed and `priv/scenarios/smoke_test.toml` exists
- **THEN** the system SHALL load the scenario file, execute all steps in order, and print results

#### Scenario: List available scenarios
- **WHEN** `mix goodwizard.scenario list` is executed
- **THEN** the system SHALL list all `.toml` files in `priv/scenarios/` with their names and descriptions

#### Scenario: Missing scenario file
- **WHEN** `mix goodwizard.scenario run nonexistent` is executed and no matching file exists
- **THEN** the system SHALL print an error message listing available scenarios

### Requirement: Structured output

The system SHALL print results in a structured format with clearly delimited sections.

#### Scenario: Output format
- **WHEN** a scenario completes (pass or fail)
- **THEN** the output SHALL include: scenario name, status (PASS/FAIL/ERROR), total duration, per-step results (query text, response, tool calls with args/timing/status), captured log entries (warnings and errors), and assertion results

#### Scenario: Progress reporting
- **WHEN** a multi-step scenario is running
- **THEN** the system SHALL print a progress line before each step so the caller knows execution is not hung

### Requirement: Workspace isolation

The system SHALL create an isolated temp workspace for each scenario run by default.

#### Scenario: Temp workspace creation
- **WHEN** a scenario runs without `--workspace`
- **THEN** the system SHALL create a temp directory with the required subdirectory structure (`memory/`, `sessions/`, `skills/`, `brain/schemas/`) and copy bootstrap files from the real workspace

#### Scenario: Temp workspace cleanup
- **WHEN** a scenario completes and `--no-cleanup` is not specified
- **THEN** the system SHALL delete the temp workspace

#### Scenario: No-cleanup mode
- **WHEN** `--no-cleanup` is specified
- **THEN** the system SHALL print the temp workspace path and leave it intact for inspection
