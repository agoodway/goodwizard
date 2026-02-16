## 1. Parser Module

- [ ] 1.1 Create `lib/goodwizard/heartbeat/parser.ex` with `Goodwizard.Heartbeat.Parser` module, `@moduledoc`, and `@task_list_regex ~r/^- \[([ x])\] (.+)$/m`
- [ ] 1.2 Implement `structured?(content)` — returns `true` if any line matches the task-list regex, `false` otherwise
- [ ] 1.3 Implement `parse(content)` — returns `{:structured, checks}` with a list of `%{index: n, text: "..."}` maps, or `{:plain, content}` if no task-list lines found

## 2. Structured Prompt

- [ ] 2.1 Implement `build_prompt(checks)` in `Goodwizard.Heartbeat.Parser` — takes a list of check maps and returns the numbered instruction string with preamble: `"Process each of the following awareness checks and report on each:\n1. ..."`

## 3. Heartbeat Integration

- [ ] 3.1 Modify `process_changed_file/2` in `Goodwizard.Heartbeat` to call `Parser.parse(content)` and branch on `{:structured, checks}` vs `{:plain, content}`
- [ ] 3.2 Modify `dispatch_heartbeat/2` to accept a third argument for optional checks metadata; when checks are present, include `metadata: %{checks: checks}` in the `Messaging.save_message/1` call for the user message
- [ ] 3.3 When structured mode is detected, pass `Parser.build_prompt(checks)` as the content to `GoodwizardAgent.ask_sync/3` instead of raw file content

## 4. UpdateChecks Action

- [ ] 4.1 Create `lib/goodwizard/actions/heartbeat/update_checks.ex` with `Goodwizard.Actions.Heartbeat.UpdateChecks` action, schema: `operation` (string, required: "add"/"remove"/"list"), `text` (string, optional — required for add/remove)
- [ ] 4.2 Implement `add` operation: read HEARTBEAT.md (or create if missing), parse existing checks, reject duplicates, append `- [ ] <text>` line, write file
- [ ] 4.3 Implement `remove` operation: read HEARTBEAT.md, find and remove matching check line, write file, error if not found
- [ ] 4.4 Implement `list` operation: read HEARTBEAT.md, parse with `Heartbeat.Parser`, return list of check texts
- [ ] 4.5 Add `Goodwizard.Actions.Heartbeat.UpdateChecks` to tools list in `lib/goodwizard/agent.ex`

## 5. System Prompt Guidance

- [ ] 5.1 Add default `TOOLS.md` content with "Scheduling & Monitoring" section to `mix goodwizard.setup` bootstrap file seeding (heartbeat vs cron decision guidance)

## 6. Tests

- [ ] 6.1 Create `test/goodwizard/heartbeat/parser_test.exs` with unit tests for `structured?/1`: positive (task-list lines), negative (plain text), mixed (task-list + prose)
- [ ] 6.2 Add unit tests for `parse/1`: multiple checks extraction, single check, no checks fallback, checked (`[x]`) and unchecked (`[ ]`) items
- [ ] 6.3 Add unit tests for `build_prompt/1`: multiple checks produce numbered list with preamble, single check
- [ ] 6.4 Add integration test for structured heartbeat dispatch: mock agent, verify structured prompt is sent, verify checks metadata is present in saved message
- [ ] 6.5 Add backwards compatibility test: plain text HEARTBEAT.md still dispatches as single blob with no checks metadata
- [ ] 6.6 Create `test/goodwizard/actions/heartbeat/update_checks_test.exs` with tests for add (new file, existing file, duplicate rejection), remove (existing check, missing check), and list (populated, empty/missing file)
