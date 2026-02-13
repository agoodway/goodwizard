# Phase 6: Memory and Session Persistence — Tasks

## Backend

- [ ] 1.1 Create Goodwizard.Skills.Memory skill (state_key :memory, mount loads MEMORY.md from workspace)
- [ ] 1.2 Create Goodwizard.Actions.Memory.ReadLongTerm action (read MEMORY.md content)
- [ ] 1.3 Create Goodwizard.Actions.Memory.WriteLongTerm action (write MEMORY.md, update skill state)
- [ ] 1.4 Create Goodwizard.Actions.Memory.AppendHistory action (timestamped entry to HISTORY.md)
- [ ] 1.5 Create Goodwizard.Actions.Memory.SearchHistory action (pattern search in HISTORY.md)
- [ ] 1.6 Create Goodwizard.Actions.Memory.Consolidate action (LLM-driven: format old messages, call LLM for JSON, parse, update memory + history, trim session)
- [ ] 1.7 Add JSONL session persistence to Session skill (load_session/2, save_session/3 with metadata + messages)
- [ ] 1.8 Register memory actions as additional tools on the agent (dynamic tool registration)
- [ ] 1.9 Hook consolidation into on_before_cmd/2 — check message count, trigger if over memory_window
- [ ] 1.10 Include memory content in ContextBuilder system prompt

## Test

- [ ] 2.1 Test Memory: read/write long term content
- [ ] 2.2 Test Memory: append and search history
- [ ] 2.3 Test Consolidate: mock LLM, verify MEMORY.md and HISTORY.md updated, session trimmed
- [ ] 2.4 Test Session persistence: save → load, verify messages survive
- [ ] 2.5 Test JSONL format: first line metadata, rest messages
