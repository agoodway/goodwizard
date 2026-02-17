## 1. Procedure Creation

- [ ] 1.1 Create `lib/goodwizard/memory/procedural.ex` with module attributes for `@procedure_types` (`workflow`, `preference`, `rule`, `strategy`, `tool_usage`), `@confidence_levels` (`high`, `medium`, `low`), and `@source_types` (`learned`, `taught`, `inferred`)
- [ ] 1.2 Implement `create/3` — accepts `memory_dir`, `frontmatter` map, and `body` string. Auto-generates UUID7 id, `created_at`, and `updated_at` timestamps. Sets `usage_count`, `success_count`, `failure_count` to 0 and `last_used` to nil. Validates required fields (`type`, `summary`, `source`) and allowed values. Defaults `confidence` to `"medium"` if not provided. Writes file to `memory/procedural/<id>.md`. Returns `{:ok, frontmatter}` or `{:error, reason}`
- [ ] 1.3 Implement validation helpers — `validate_required/1` checks presence of type, summary, source; `validate_type/1` checks type is in `@procedure_types`; `validate_confidence/1` checks confidence is in `@confidence_levels`; `validate_source/1` checks source is in `@source_types`

## 2. Procedure Read, Update, and Delete

- [ ] 2.1 Implement `read/2` — accepts `memory_dir` and `id`, reads and parses the procedure file, returns `{:ok, {frontmatter, body}}` or `{:error, :not_found}`
- [ ] 2.2 Implement `update/4` — accepts `memory_dir`, `id`, `frontmatter_updates` map, and optional `body` (nil to keep existing). Reads existing procedure, merges frontmatter updates (preserving auto-managed fields: id, created_at, usage_count, success_count, failure_count, last_used), sets `updated_at` to current timestamp, validates merged frontmatter, writes updated file. Returns `{:ok, merged_frontmatter}` or `{:error, reason}`
- [ ] 2.3 Implement `delete/2` — accepts `memory_dir` and `id`, deletes the procedure file, returns `:ok` or `{:error, :not_found}`

## 3. Procedure Listing

- [ ] 3.1 Implement `list/2` — accepts `memory_dir` and keyword opts (`limit`, `type`, `confidence`, `tags`, `min_usage_count`). Scans all `.md` files in `memory/procedural/`, parses frontmatter only, applies filters, sorts by `updated_at` descending, applies limit (default 20). Returns `{:ok, [frontmatter_map]}`
- [ ] 3.2 Implement filter helpers — `filter_by_type/2`, `filter_by_confidence/2` (minimum level: low < medium < high), `filter_by_tags/2` (intersection match), `filter_by_min_usage/2`

## 4. Recall Scoring

- [ ] 4.1 Implement `recall/3` — accepts `memory_dir`, `situation` string, and keyword opts (`limit`, `type`, `tags`, `min_confidence`). Lists all procedures, applies metadata filters, computes a relevance score for each, sorts by score descending, applies limit (default 5). Returns `{:ok, [frontmatter_map_with_score]}`
- [ ] 4.2 Implement `compute_score/3` — accepts a procedure frontmatter map, the situation string, and query tags. Computes the weighted score: `tag_match * 0.4 + text_relevance * 0.3 + confidence_score * 0.2 + recency_score * 0.1`
- [ ] 4.3 Implement scoring helpers — `tag_match_score/2` (Jaccard-like fraction of query tags matching procedure tags), `text_relevance_score/2` (fraction of situation words found in summary + body, case-insensitive), `confidence_score/1` (high=1.0, medium=0.6, low=0.3), `recency_score/1` (linear decay over 90 days from `last_used`, 0 if never used)

## 5. Usage Tracking

- [ ] 5.1 Implement `record_usage/3` — accepts `memory_dir`, `id`, and `outcome` (`:success` or `:failure`). Reads the procedure, increments `usage_count` and the corresponding count (`success_count` or `failure_count`), updates `last_used` to current timestamp, evaluates confidence adjustment, writes updated file. Returns `{:ok, updated_frontmatter}`
- [ ] 5.2 Implement `adjust_confidence/1` — accepts frontmatter map, evaluates promotion/demotion rules: promote low->medium at 3 successes, medium->high at 5 successes; demote high->medium at 2 failures, medium->low at 3 failures. Returns updated confidence string

## 6. Tests

- [ ] 6.1 Write unit tests in `test/goodwizard/memory/procedural_test.exs` for create: auto-generated id and timestamps, required field validation, type/confidence/source validation, default confidence is medium, usage counts start at 0, file written to correct path
- [ ] 6.2 Write unit tests for read: read existing procedure, read non-existent returns error
- [ ] 6.3 Write unit tests for update: merge frontmatter updates, replace body, preserve auto-managed fields (id, created_at, usage counts), update `updated_at`, update non-existent returns error
- [ ] 6.4 Write unit tests for delete: delete existing procedure, delete non-existent returns error
- [ ] 6.5 Write unit tests for list: all procedures returned, filter by type, filter by confidence, filter by tags, filter by min_usage_count, limit respected, sorted by updated_at descending, empty directory returns empty list
- [ ] 6.6 Write unit tests for recall: scored ranking with known inputs, tag match dominance, confidence weighting, recency effect, empty store returns empty list, limit respected
- [ ] 6.7 Write unit tests for usage tracking: success increments success_count and usage_count, failure increments failure_count and usage_count, last_used updated, confidence promotion (low->medium at 3 successes, medium->high at 5), confidence demotion (high->medium at 2 failures, medium->low at 3)

## 7. Verification

- [ ] 7.1 Run `mix compile --warnings-as-errors`
- [ ] 7.2 Run `mix format --check-formatted`
- [ ] 7.3 Run `mix test` and verify no new failures
