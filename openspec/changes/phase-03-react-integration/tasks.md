# Phase 3: ReAct Integration — Tasks

## Backend

- [x] 1.1 Create `Goodwizard.Character` module — `use Jido.Character` with name, role, personality (traits + values), voice (tone + style), instructions
- [x] 1.2 Create `Goodwizard.Character.Hydrator` — `hydrate/2` creates base character, applies config overrides, injects bootstrap files as knowledge (category: "workspace"), renders via `to_context/2`
- [x] 1.3 Implement `Hydrator.inject_memory/2` and `Hydrator.inject_skills/2` as composable enrichment functions (used by later phases)
- [x] 1.4 Slim `Goodwizard.ContextBuilder` to message ops only — `build_messages/1`, `add_tool_result/4`, `add_assistant_message/3` (remove `build_system_prompt/2`)
- [x] 1.5 Verify all Phase 2 actions convert correctly via Jido.AI.ToolAdapter.from_actions/1 (name, description, parameter_schema)
- [x] 1.6 Verify Jido.AI.Executor dispatches tool calls to actions with correct argument normalization

## Test

- [x] 2.1 Test Character module produces valid struct with expected name, role, personality, voice, instructions
- [x] 2.2 Test Hydrator.hydrate/2 loads bootstrap files from workspace as knowledge items with category "workspace"
- [x] 2.3 Test Hydrator applies config overrides (name, tone, style, traits) when Config.get(:character) returns non-nil
- [x] 2.4 Test Hydrator.inject_memory/2 adds knowledge with category "long-term-memory"
- [x] 2.5 Test Hydrator.inject_skills/2 adds instruction for skills summary and knowledge for active skills
- [x] 2.6 Test Hydrator.hydrate/2 renders to system prompt string via to_context/2
- [x] 2.7 Test ContextBuilder.build_messages/1 builds [system, ...history, user] message list
- [x] 2.8 Test ContextBuilder.add_tool_result/4 and add_assistant_message/3
- [x] 2.9 Test ToolAdapter produces correct ReqLLM tool definitions from action modules
- [x] 2.10 Test Executor executes tools by name with string-to-atom key normalization
