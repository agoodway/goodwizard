### Requirement: Response content assertions

The system SHALL evaluate assertions against query responses.

#### Scenario: response_contains passes
- **WHEN** assertion `type = "response_contains"`, `step_index = 0`, `value = "Goodwizard"` is evaluated and step 0's response contains "Goodwizard" (case-insensitive)
- **THEN** the assertion SHALL pass

#### Scenario: response_contains fails
- **WHEN** assertion `type = "response_contains"` is evaluated and the response does not contain the value
- **THEN** the assertion SHALL fail with a message indicating the missing value

### Requirement: Log-level assertions

#### Scenario: no_errors passes
- **WHEN** assertion `type = "no_errors"` is evaluated and no error-level log entries were captured during the run
- **THEN** the assertion SHALL pass

#### Scenario: no_errors fails
- **WHEN** error-level log entries were captured
- **THEN** the assertion SHALL fail with the count of errors found

### Requirement: Tool usage assertions

#### Scenario: tool_called passes
- **WHEN** assertion `type = "tool_called"`, `value = "read_file"` is evaluated and the `read_file` tool was called at least once during the run
- **THEN** the assertion SHALL pass

#### Scenario: tool_not_called passes
- **WHEN** assertion `type = "tool_not_called"`, `value = "exec"` is evaluated and the `exec` tool was never called
- **THEN** the assertion SHALL pass

### Requirement: Budget assertions

#### Scenario: max_duration_ms
- **WHEN** assertion `type = "max_duration_ms"`, `value = 30000` is evaluated and total duration was under 30 seconds
- **THEN** the assertion SHALL pass

#### Scenario: max_tool_calls
- **WHEN** assertion `type = "max_tool_calls"`, `value = 10` is evaluated and fewer than 10 tool calls were made
- **THEN** the assertion SHALL pass
