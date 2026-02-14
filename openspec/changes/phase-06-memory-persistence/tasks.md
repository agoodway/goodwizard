# Phase 6: Memory and Session Persistence — Tasks

## Backend

- [x] 1.1 Create Goodwizard.Skills.Memory skill (state_key :memory, mount loads MEMORY.md from workspace)
- [x] 1.2 Create Goodwizard.Actions.Memory.ReadLongTerm action (read MEMORY.md content)
- [x] 1.3 Create Goodwizard.Actions.Memory.WriteLongTerm action (write MEMORY.md, update skill state)
- [x] 1.4 Create Goodwizard.Actions.Memory.AppendHistory action (timestamped entry to HISTORY.md)
- [x] 1.5 Create Goodwizard.Actions.Memory.SearchHistory action (pattern search in HISTORY.md)
- [x] 1.6 Create Goodwizard.Actions.Memory.Consolidate action (LLM-driven: format old messages, call LLM for JSON, parse, update memory + history, trim session)
- [x] 1.7 Add JSONL session persistence to Session skill (load_session/2, save_session/3 with metadata + messages)
- [x] 1.8 Register memory actions as additional tools on the agent (dynamic tool registration)
- [x] 1.9 Hook consolidation into on_before_cmd/2 — check message count, trigger if over memory_window
- [x] 1.10 Include memory content via Hydrator.inject_memory/2 — pass memory_content in opts to hydrate/2, which adds it as knowledge (category: "long-term-memory")

## Test

- [x] 2.1 Test Memory: read/write long term content
- [x] 2.2 Test Memory: append and search history
- [x] 2.3 Test Consolidate: mock LLM, verify MEMORY.md and HISTORY.md updated, session trimmed
- [x] 2.4 Test Session persistence: save → load, verify messages survive
- [x] 2.5 Test JSONL format: first line metadata, rest messages
