# Phase 4: Agent Definition — Tasks

## Backend

- [ ] 1.1 Create Goodwizard.Agent module using `use Jido.AI.ReActAgent` with tools, model, and max_iterations
- [ ] 1.2 Create Goodwizard.Skills.Session skill (state_key :session, schema with messages/created_at/metadata, mount/2)
- [ ] 1.3 Implement Session helper functions: add_message/4, get_history/2, clear/1
- [ ] 1.4 Override on_before_cmd/2 to build dynamic system prompt via ContextBuilder from workspace state
- [ ] 1.5 Override on_after_cmd/3 to update session with query and response

## Test

- [ ] 2.1 Test Agent starts via Jido instance with correct state
- [ ] 2.2 Test ask_sync returns response with mocked LLM (no tools)
- [ ] 2.3 Test ask_sync with tool call (mocked LLM triggers read_file, returns result)
- [ ] 2.4 Test Session skill: add messages, get history with limit, clear
- [ ] 2.5 Test dynamic system prompt includes workspace bootstrap files
