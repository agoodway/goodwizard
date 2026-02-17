## 1. RecordEpisode Action

- [x] 1.1 Create `lib/goodwizard/actions/memory/episodic/record_episode.ex` with `use Jido.Action` and schema params: `type` (required, enum), `summary` (required, string, max 200), `tags` (list of strings), `outcome` (required, enum), `entities_involved` (list of strings), `observation` (required, string), `approach` (required, string), `result` (required, string), `lessons` (optional, string)
- [x] 1.2 Implement `run/2` to resolve memory directory from context, build frontmatter and markdown body from params, call `Memory.Episodic.create/3`, return `%{episode: ..., message: "..."}`
- [x] 1.3 Add memory directory resolution helper (check context state, fall back to Config)

## 2. SearchEpisodes Action

- [x] 2.1 Create `lib/goodwizard/actions/memory/episodic/search_episodes.ex` with schema params: `query` (optional, string), `tags` (list of strings), `type` (optional, string), `outcome` (optional, string), `limit` (integer, default 10)
- [x] 2.2 Implement `run/2` to resolve memory directory, build filter opts from non-nil params, call `Memory.Episodic.search/3`, return `%{episodes: ..., count: ...}`

## 3. ReadEpisode Action

- [x] 3.1 Create `lib/goodwizard/actions/memory/episodic/read_episode.ex` with schema param: `id` (required, string)
- [x] 3.2 Implement `run/2` to resolve memory directory, call `Memory.Episodic.read/2`, return `%{frontmatter: ..., body: ...}`

## 4. ListEpisodes Action

- [x] 4.1 Create `lib/goodwizard/actions/memory/episodic/list_episodes.ex` with schema params: `limit` (integer, default 20), `type` (optional, string), `outcome` (optional, string)
- [x] 4.2 Implement `run/2` to resolve memory directory, build filter opts, call `Memory.Episodic.list/2`, return `%{episodes: ..., count: ...}`

## 5. Tool Registration

- [x] 5.1 Add `Goodwizard.Actions.Memory.Episodic.RecordEpisode` to the `tools:` list in `lib/goodwizard/agent.ex`
- [x] 5.2 Add `Goodwizard.Actions.Memory.Episodic.SearchEpisodes` to the `tools:` list
- [x] 5.3 Add `Goodwizard.Actions.Memory.Episodic.ReadEpisode` to the `tools:` list
- [x] 5.4 Add `Goodwizard.Actions.Memory.Episodic.ListEpisodes` to the `tools:` list

## 6. Tests

- [x] 6.1 Create `test/goodwizard/actions/memory/episodic/record_episode_test.exs`: test successful episode creation with all required params, verify frontmatter contains auto-generated id and timestamp, verify body contains observation/approach/result/lessons sections, test summary truncation at 200 chars
- [x] 6.2 Create `test/goodwizard/actions/memory/episodic/search_episodes_test.exs`: test search by text query finds matching episodes, test filter by tags/type/outcome, test empty results return, test limit is respected
- [x] 6.3 Create `test/goodwizard/actions/memory/episodic/read_episode_test.exs`: test reading an existing episode returns frontmatter and body, test reading a nonexistent ID returns error
- [x] 6.4 Create `test/goodwizard/actions/memory/episodic/list_episodes_test.exs`: test listing returns episodes sorted by timestamp descending, test type and outcome filters, test limit param, test empty directory returns empty list
