# Phase 4: Agent Definition — Tasks

## Backend

- [x] 1.1 Create Goodwizard.Agent module using `use Jido.AI.ReActAgent` with tools, model, and max_iterations
- [x] 1.2 Create Goodwizard.Skills.Session skill (state_key :session, schema with messages/created_at/metadata, mount/2)
- [x] 1.3 Implement Session helper functions: add_message/4, get_history/2, clear/1
- [x] 1.4 Override on_before_cmd/2 to build dynamic system prompt via Hydrator.hydrate/2 from workspace state (apply character_overrides from agent initial_state if present)
- [x] 1.5 Override on_after_cmd/3 to update session with query and response

## Test

- [x] 2.1 Test Agent starts via Jido instance with correct state
- [x] 2.2 Test ask_sync returns response with mocked LLM (no tools)
- [x] 2.3 Test ask_sync with tool call (mocked LLM triggers read_file, returns result)
- [x] 2.4 Test Session skill: add messages, get history with limit, clear
- [x] 2.5 Test dynamic system prompt includes workspace bootstrap files
