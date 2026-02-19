## 1. Create LoadMemoryContext Action

- [x] 1.1 Create `lib/goodwizard/actions/memory/load_context.ex` with `LoadMemoryContext` action module using `Jido.Action` with schema params: `topic` (string, default ""), `max_episodes` (integer, default 5), `max_procedures` (integer, default 3)
- [x] 1.2 Implement recent episode loading: always load the 3 most recent episodes via `Memory.Episodic.list/2`
- [x] 1.3 Implement topic-relevant episode loading: when `topic` is non-empty, search for additional episodes via `Memory.Episodic.search/3` and merge with recent episodes
- [x] 1.4 Implement episode deduplication by ID and cap at `max_episodes`
- [x] 1.5 Implement procedure loading: when `topic` is non-empty, use `Memory.Procedural.recall/3`; otherwise fall back to `Memory.Procedural.list/2` ordered by confidence/usage
- [x] 1.6 Cap procedures at `max_procedures`

## 2. Format Memory Context

- [x] 2.1 Implement `format_memory_context/2` that combines episodes and procedures into a markdown string with "Relevant Past Experiences" and "Relevant Procedures" sections
- [x] 2.2 Implement `format_episodes/1` that renders each episode as a compact block: timestamp, type, outcome, summary, and key lesson (from body)
- [x] 2.3 Implement `format_procedures/1` that renders each procedure as a compact block: summary, confidence level, and when-to-apply trigger
- [x] 2.4 Handle empty lists gracefully (omit section entirely if no episodes or no procedures)

## 3. Integrate into Channel Handlers

- [x] 3.1 Add memory context loading in `lib/goodwizard/channels/cli.ex` on first message of a new session: call `LoadMemoryContext` action with the first user message as `topic`, append result to system prompt
- [x] 3.2 Add memory context loading in `lib/goodwizard/channels/telegram.ex` on first message of a new session: same integration as CLI
- [x] 3.3 Add graceful error handling in both handlers: if `LoadMemoryContext` fails, log a debug warning and proceed without memory context

## 4. Register Action

- [x] 4.1 Add `Goodwizard.Actions.Memory.LoadContext` to the agent's tool list in `lib/goodwizard/plugins/tools.ex` (the agent may also call this explicitly mid-conversation)

## 5. Tests

- [x] 5.1 Add test: `LoadMemoryContext` returns formatted context with recent episodes when no topic is provided
- [x] 5.2 Add test: `LoadMemoryContext` returns topic-relevant episodes when topic is provided
- [x] 5.3 Add test: episodes are deduplicated by ID when recent and topic-relevant sets overlap
- [x] 5.4 Add test: total episodes are capped at `max_episodes`
- [x] 5.5 Add test: procedures are loaded via recall when topic is provided
- [x] 5.6 Add test: procedures fall back to list when no topic is provided
- [x] 5.7 Add test: procedures are capped at `max_procedures`
- [x] 5.8 Add test: empty episodic store returns context without the episodes section
- [x] 5.9 Add test: empty procedural store returns context without the procedures section
- [x] 5.10 Add test: both stores empty returns empty context string
- [x] 5.11 Add test: formatted context uses markdown with readable episode summaries
- [x] 5.12 Add test: formatted context uses markdown with readable procedure summaries
