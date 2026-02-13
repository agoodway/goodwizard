# Phase 3: ReAct Integration — Tasks

## Backend

- [ ] 1.1 Create Goodwizard.ContextBuilder.build_system_prompt/2 — identity section, bootstrap files from workspace, memory, skills summary
- [ ] 1.2 Create Goodwizard.ContextBuilder.build_messages/1 — complete message list [system, ...history, user]
- [ ] 1.3 Create Goodwizard.ContextBuilder.add_tool_result/4 and add_assistant_message/3
- [ ] 1.4 Verify all Phase 2 actions convert correctly via Jido.AI.ToolAdapter.from_actions/1 (name, description, parameter_schema)
- [ ] 1.5 Verify Jido.AI.Executor dispatches tool calls to actions with correct argument normalization

## Test

- [ ] 2.1 Test ContextBuilder includes identity section with name, time, workspace
- [ ] 2.2 Test ContextBuilder loads bootstrap files from workspace
- [ ] 2.3 Test ContextBuilder builds complete message list and adds tool results
- [ ] 2.4 Test ToolAdapter produces correct ReqLLM tool definitions from action modules
- [ ] 2.5 Test Executor executes tools by name with string-to-atom key normalization
