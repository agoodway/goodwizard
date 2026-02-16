## 1. Step Struct

- [ ] 1.1 Create `lib/goodwizard/workflow/step.ex` with `defstruct` for Step: `type`, `command`, `flags` (default `%{}`), `stdin_ref` (default `nil`), `condition` (default `nil`), `id` (default `nil`). Enforce `type` key.
- [ ] 1.2 Add `@type t()` typespec for the Step struct

## 2. Pipeline Struct

- [ ] 2.1 Create `lib/goodwizard/workflow/pipeline.ex` with `defstruct` for Pipeline: `steps` (default `[]`), `name` (default `nil`), `timeout_ms` (default `20_000`), `max_stdout_bytes` (default `512_000`). Enforce `steps` key.
- [ ] 2.2 Add `@type t()` typespec for the Pipeline struct

## 3. ApprovalRequest Struct

- [ ] 3.1 Create `lib/goodwizard/workflow/approval_request.ex` with `defstruct` for ApprovalRequest: `prompt`, `preview_items` (default `[]`), `token`, `step_index`. Enforce `prompt` and `token` keys.
- [ ] 3.2 Add `@type t()` typespec for the ApprovalRequest struct

## 4. Envelope Module

- [ ] 4.1 Create `lib/goodwizard/workflow/envelope.ex` with `ok/1`, `needs_approval/1`, and `cancelled/1` functions returning Jason-encodable maps
- [ ] 4.2 `ok/1` accepts a result map and returns `%{"status" => "ok", "result" => result}`
- [ ] 4.3 `needs_approval/1` accepts an ApprovalRequest and returns `%{"status" => "needs_approval", "prompt" => ..., "preview_items" => ..., "token" => ...}`
- [ ] 4.4 `cancelled/1` accepts a reason string and returns `%{"status" => "cancelled", "reason" => reason}`

## 5. Tests

- [ ] 5.1 Add tests for Step struct creation with all field combinations, enforce_keys validation
- [ ] 5.2 Add tests for Pipeline struct defaults and step ordering
- [ ] 5.3 Add tests for ApprovalRequest struct creation and defaults
- [ ] 5.4 Add tests for Envelope.ok/1, needs_approval/1, and cancelled/1 — verify output shape and Jason encoding
