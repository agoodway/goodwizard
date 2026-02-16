## ADDED Requirements

### Requirement: Envelope formats a successful pipeline result

The `Goodwizard.Workflow.Envelope` module SHALL provide an `ok/1` function that accepts a result map and returns a Jason-encodable map with `"status"` set to `"ok"` and `"result"` containing the pipeline output.

#### Scenario: Format a successful result

- **WHEN** `Envelope.ok(%{stdout: "hello", exit_code: 0})` is called
- **THEN** it returns `%{"status" => "ok", "result" => %{stdout: "hello", exit_code: 0}}`

#### Scenario: Ok envelope is Jason-encodable

- **WHEN** the return value of `Envelope.ok/1` is passed to `Jason.encode/1`
- **THEN** encoding succeeds without error

### Requirement: Envelope formats a needs_approval halt

The `Envelope` module SHALL provide a `needs_approval/1` function that accepts an `ApprovalRequest` struct and returns a Jason-encodable map with `"status"` set to `"needs_approval"` and the approval request details.

#### Scenario: Format an approval halt

- **WHEN** `Envelope.needs_approval(approval_request)` is called with a valid ApprovalRequest
- **THEN** it returns a map with `"status" => "needs_approval"`, `"prompt"`, `"preview_items"`, and `"token"` fields

#### Scenario: Needs_approval envelope includes the resume token

- **WHEN** an ApprovalRequest with token `"abc123"` is formatted
- **THEN** the envelope contains `"token" => "abc123"` for the caller to use when resuming

### Requirement: Envelope formats a cancelled pipeline result

The `Envelope` module SHALL provide a `cancelled/1` function that accepts a reason string and returns a Jason-encodable map with `"status"` set to `"cancelled"` and `"reason"` containing the explanation.

#### Scenario: Format a cancellation

- **WHEN** `Envelope.cancelled("User denied approval")` is called
- **THEN** it returns `%{"status" => "cancelled", "reason" => "User denied approval"}`

#### Scenario: Cancelled envelope is Jason-encodable

- **WHEN** the return value of `Envelope.cancelled/1` is passed to `Jason.encode/1`
- **THEN** encoding succeeds without error
