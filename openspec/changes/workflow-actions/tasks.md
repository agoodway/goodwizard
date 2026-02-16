## 1. Config Additions

- [ ] 1.1 Add `[workflow]` defaults to `Goodwizard.Config`: `enabled` (false), `default_timeout_ms` (20000), `max_stdout_bytes` (512000), `state_ttl_minutes` (60)
- [ ] 1.2 Add `[workflow]` section documentation to config.toml template

## 2. Run Action

- [ ] 2.1 Create `lib/goodwizard/actions/workflow/run.ex` with `use Jido.Action`, name `"workflow_run"`, schema with `pipeline` (required string), `timeout_ms` (optional integer), `max_stdout_bytes` (optional integer), `cwd` (optional string), `args_json` (optional string)
- [ ] 2.2 Implement `workflow.enabled` config guard at start of `run/2`
- [ ] 2.3 Implement dispatch heuristic: file extension check for `.workflow`/`.yaml`/`.yml` vs pipe string
- [ ] 2.4 Call `PipelineParser.parse/1` or `WorkflowFile.parse_file/2` based on dispatch
- [ ] 2.5 Call `Runner.run/2` with parsed pipeline and merged opts (config defaults + param overrides)
- [ ] 2.6 Return Runner's Envelope output as action result

## 3. Resume Action

- [ ] 3.1 Create `lib/goodwizard/actions/workflow/resume.ex` with `use Jido.Action`, name `"workflow_resume"`, schema with `token` (required string), `approve` (required boolean)
- [ ] 3.2 Implement `workflow.enabled` config guard
- [ ] 3.3 Call `Runner.resume/2` with token and decision
- [ ] 3.4 Return Runner's Envelope output as action result
- [ ] 3.5 Handle `{:error, :state_not_found}` with user-friendly message

## 4. Agent Registration

- [ ] 4.1 Add `Goodwizard.Actions.Workflow.Run` and `Goodwizard.Actions.Workflow.Resume` to agent tool list in `lib/goodwizard/agent.ex`

## 5. Tests

- [ ] 5.1 Tests for Run action: pipe string dispatch, file path dispatch, config guard, timeout override
- [ ] 5.2 Tests for Resume action: approve flow, deny flow, invalid token, config guard
- [ ] 5.3 Tests for config defaults and TOML override
- [ ] 5.4 Tests for agent tool list includes both workflow actions
