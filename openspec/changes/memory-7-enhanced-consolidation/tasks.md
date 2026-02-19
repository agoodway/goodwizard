## 1. Refactor Consolidation Prompt

- [x] 1.1 Replace `@consolidation_prompt` in `lib/goodwizard/actions/memory/consolidate.ex` with the new three-section extraction prompt that requests `episodes`, `memory_profile_update`, and `procedural_insights` in JSON
- [x] 1.2 Add procedure summary loading: before calling the LLM, read all procedure frontmatter via `Memory.Procedural.list/2` and format as context for the prompt
- [x] 1.3 Update `build_prompt/2` to accept and include procedure summaries alongside current memory content and formatted messages

## 2. Update Response Parsing

- [x] 2.1 Update `parse_json_response/1` to accept the new three-key JSON format (`episodes`, `memory_profile_update`, `procedural_insights`) instead of the old two-key format (`history_entry`, `memory_update`)
- [x] 2.2 Make `episodes` and `procedural_insights` arrays optional in validation (default to empty arrays if absent)
- [x] 2.3 Validate each episode object has required fields: `type`, `summary`, `outcome`, `observation`, `approach`, `result`
- [x] 2.4 Validate each procedural insight object has required fields: `type`, `summary`, `when_to_apply`, `steps`

## 3. Update Write Logic

- [x] 3.1 Replace `append_history/2` with `write_audit_log/3` that appends a structured consolidation summary to HISTORY.md (episode count, procedure count, summaries)
- [x] 3.2 Add `write_episodes/2` that iterates over extracted episodes and calls `Memory.Episodic.create/3` for each, collecting successes and failures
- [x] 3.3 Add `write_procedures/2` that iterates over procedural insights, calling `Memory.Procedural.create/3` for new ones and `Memory.Procedural.update/4` for ones with `updates_existing` set
- [x] 3.4 Update `do_consolidate/5` to call all three write functions and aggregate results
- [x] 3.5 Update the success return map to include `episodes_created`, `procedures_created`, `procedures_updated` counts

## 4. Graceful Error Handling

- [x] 4.1 Wrap each episode/procedure write in error handling so a single failure does not abort the entire consolidation
- [x] 4.2 Log warnings for individual write failures with the failed item's summary
- [x] 4.3 Include failure counts in the consolidation result map

## 5. Tests

- [x] 5.1 Update existing consolidation tests to expect the new response format and multi-store writes
- [x] 5.2 Add test: consolidation extracts episodes and writes them to `memory/episodic/`
- [x] 5.3 Add test: consolidation extracts procedural insights and writes them to `memory/procedural/`
- [x] 5.4 Add test: consolidation updates MEMORY.md with semantic profile changes
- [x] 5.5 Add test: consolidation appends audit log entry to HISTORY.md with correct format
- [x] 5.6 Add test: existing procedures are included in the LLM prompt for deduplication
- [x] 5.7 Add test: `updates_existing` procedural insight calls `Memory.Procedural.update/4` instead of `create/3`
- [x] 5.8 Add test: individual episode write failure does not block other writes
- [x] 5.9 Add test: LLM response with empty `episodes` and `procedural_insights` arrays still updates MEMORY.md
- [x] 5.10 Add test: LLM response missing optional arrays defaults to empty (no crash)
