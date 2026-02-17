## 1. LearnProcedure Action

- [ ] 1.1 Create `lib/goodwizard/actions/memory/procedural/learn_procedure.ex` with `use Jido.Action` and schema params: `type` (required, enum of workflow/preference/rule/strategy/tool_usage), `summary` (required, string, max 200), `tags` (list of strings), `confidence` (enum, default medium), `source` (required, enum of learned/taught/inferred), `when_to_apply` (required, string), `steps` (required, string), `notes` (optional, string)
- [ ] 1.2 Implement `run/2` to resolve memory directory, build frontmatter and markdown body from params, call `Memory.Procedural.create/3`, return `%{procedure: ..., message: "..."}`
- [ ] 1.3 Add memory directory resolution helper (check context state, fall back to Config)

## 2. RecallProcedures Action

- [ ] 2.1 Create `lib/goodwizard/actions/memory/procedural/recall_procedures.ex` with schema params: `situation` (required, string), `tags` (list of strings), `type` (optional, string), `limit` (integer, default 5)
- [ ] 2.2 Implement `run/2` to resolve memory directory, build opts, call `Memory.Procedural.recall/3`, return `%{procedures: ..., count: ...}`

## 3. UpdateProcedure Action

- [ ] 3.1 Create `lib/goodwizard/actions/memory/procedural/update_procedure.ex` with schema params: `id` (required, string), `summary` (optional, string), `tags` (optional, list of strings), `confidence` (optional, enum), `when_to_apply` (optional, string), `steps` (optional, string), `notes` (optional, string)
- [ ] 3.2 Implement `run/2` to resolve memory directory, build frontmatter updates map from non-nil params, build body string from when_to_apply/steps/notes if any body param is provided, call `Memory.Procedural.update/4`, return updated procedure

## 4. UseProcedure Action

- [ ] 4.1 Create `lib/goodwizard/actions/memory/procedural/use_procedure.ex` with schema params: `id` (required, string), `outcome` (required, enum of success/failure)
- [ ] 4.2 Implement `run/2` to resolve memory directory, call `Memory.Procedural.record_usage/3`, return `%{procedure: ..., message: "Procedure usage recorded (outcome)"}`

## 5. ListProcedures Action

- [ ] 5.1 Create `lib/goodwizard/actions/memory/procedural/list_procedures.ex` with schema params: `limit` (integer, default 20), `type` (optional, string), `confidence` (optional, string, doc: "Minimum confidence level")
- [ ] 5.2 Implement `run/2` to resolve memory directory, build filter opts, call `Memory.Procedural.list/2`, return `%{procedures: ..., count: ...}`

## 6. Tool Registration

- [ ] 6.1 Add `Goodwizard.Actions.Memory.Procedural.LearnProcedure` to the `tools:` list in `lib/goodwizard/agent.ex`
- [ ] 6.2 Add `Goodwizard.Actions.Memory.Procedural.RecallProcedures` to the `tools:` list
- [ ] 6.3 Add `Goodwizard.Actions.Memory.Procedural.UpdateProcedure` to the `tools:` list
- [ ] 6.4 Add `Goodwizard.Actions.Memory.Procedural.UseProcedure` to the `tools:` list
- [ ] 6.5 Add `Goodwizard.Actions.Memory.Procedural.ListProcedures` to the `tools:` list

## 7. Tests

- [ ] 7.1 Create `test/goodwizard/actions/memory/procedural/learn_procedure_test.exs`: test successful procedure creation with all required params, verify frontmatter contains auto-generated id/created_at/updated_at and usage_count=0, verify body contains when_to_apply/steps/notes sections, test summary truncation at 200 chars, test default confidence is "medium"
- [ ] 7.2 Create `test/goodwizard/actions/memory/procedural/recall_procedures_test.exs`: test recall with a situation description returns ranked procedures, test tag filter narrows results, test type filter narrows results, test limit is respected, test empty store returns empty list
- [ ] 7.3 Create `test/goodwizard/actions/memory/procedural/update_procedure_test.exs`: test updating summary only preserves other frontmatter and body, test updating steps/when_to_apply/notes rebuilds body, test updating confidence changes the value, test updating nonexistent ID returns error
- [ ] 7.4 Create `test/goodwizard/actions/memory/procedural/use_procedure_test.exs`: test recording success increments usage_count, test recording failure increments usage_count, test confidence promotion after repeated successes (low->medium threshold), test confidence demotion after repeated failures (high->medium threshold), test last_used timestamp is updated
- [ ] 7.5 Create `test/goodwizard/actions/memory/procedural/list_procedures_test.exs`: test listing returns procedures, test type filter, test confidence filter, test limit param, test empty directory returns empty list
