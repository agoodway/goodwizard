## 1. Episode Creation

- [ ] 1.1 Create `lib/goodwizard/memory/episodic.ex` with module attributes for `@episode_types` (`task_completion`, `problem_solved`, `error_encountered`, `decision_made`, `interaction`) and `@outcome_types` (`success`, `failure`, `partial`, `abandoned`)
- [ ] 1.2 Implement `create/3` — accepts `memory_dir`, `frontmatter` map, and `body` string. Auto-generates UUID7 id and ISO 8601 timestamp. Validates required fields (`type`, `summary`, `outcome`) and allowed values. Writes file to `memory/episodic/<id>.md` via `Memory.Entry.serialize/2`. Returns `{:ok, frontmatter}` or `{:error, reason}`
- [ ] 1.3 Implement validation helpers — `validate_required/1` checks presence of type, summary, outcome; `validate_type/1` checks type is in `@episode_types`; `validate_outcome/1` checks outcome is in `@outcome_types`; `validate_summary_length/1` checks summary is max 200 characters

## 2. Episode Read and Delete

- [ ] 2.1 Implement `read/2` — accepts `memory_dir` and `id`, reads and parses the episode file via `Memory.Entry.parse/1`, returns `{:ok, {frontmatter, body}}` or `{:error, :not_found}`
- [ ] 2.2 Implement `delete/2` — accepts `memory_dir` and `id`, deletes the episode file, returns `:ok` or `{:error, :not_found}`

## 3. Episode Listing

- [ ] 3.1 Implement `list/2` — accepts `memory_dir` and keyword opts (`limit`, `type`, `outcome`, `tags`, `after`, `before`). Scans all `.md` files in `memory/episodic/`, parses frontmatter only, applies filters, sorts by timestamp descending, applies limit (default 20). Returns `{:ok, [frontmatter_map]}` or `{:error, reason}`
- [ ] 3.2 Implement filter helpers — `filter_by_type/2`, `filter_by_outcome/2`, `filter_by_tags/2` (intersection match), `filter_by_date_range/3` (after/before using ISO 8601 string comparison)

## 4. Episode Search

- [ ] 4.1 Implement `search/3` — accepts `memory_dir`, `query` string, and keyword opts (`limit`, `type`, `outcome`, `tags`). Lists all episodes, applies metadata filters, then searches frontmatter fields and body content for case-insensitive substring match. Returns `{:ok, [frontmatter_map]}` with results sorted by timestamp descending, limited to `limit` (default 10)
- [ ] 4.2 Handle empty query string — when query is empty, behave like `list/2` with the provided filter opts

## 5. Tests

- [ ] 5.1 Write unit tests in `test/goodwizard/memory/episodic_test.exs` for create: auto-generated id and timestamp, required field validation, type validation, outcome validation, summary length enforcement, file written to correct path
- [ ] 5.2 Write unit tests for read: read existing episode, read non-existent returns error
- [ ] 5.3 Write unit tests for delete: delete existing episode, delete non-existent returns error
- [ ] 5.4 Write unit tests for list: all episodes returned, filter by type, filter by outcome, filter by tags (intersection), filter by date range, limit respected, sorted by timestamp descending, empty directory returns empty list
- [ ] 5.5 Write unit tests for search: text match in summary, text match in body, text match is case-insensitive, combined text + filter, empty query acts as list, limit respected

## 6. Verification

- [ ] 6.1 Run `mix compile --warnings-as-errors`
- [ ] 6.2 Run `mix format --check-formatted`
- [ ] 6.3 Run `mix test` and verify no new failures
