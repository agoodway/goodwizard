## 1. Episodic Archival Action

- [ ] 1.1 Create `lib/goodwizard/actions/memory/episodic/archive_old.ex` with `ArchiveOldEpisodes` action using `Jido.Action` with schema params: `file_threshold` (integer, default 200), `recent_days` (integer, default 30), `success_retention_days` (integer, default 90)
- [ ] 1.2 Implement file count check: read the episodic directory, count `.md` files, skip archival if count is at or below threshold
- [ ] 1.3 Implement retention classification: categorize each episode as "keep" (last 30 days or successful within last 90 days) or "archive candidate"
- [ ] 1.4 Implement monthly grouping: group archive candidates by calendar month (YYYY-MM)
- [ ] 1.5 Implement monthly summary generation: for each month group, create a summary episode with aggregated stats (count by type, count by outcome), key lessons extracted from episode bodies, and notable event summaries
- [ ] 1.6 Write monthly summary episodes to `memory/episodic/` with `type: "monthly_summary"` and tags including the month identifier
- [ ] 1.7 Delete individual archived episodes after their monthly summaries are successfully written
- [ ] 1.8 Return result with counts: episodes archived, summaries created, episodes retained

## 2. Procedural Confidence Decay

- [ ] 2.1 Add `decay_unused/2` function to `lib/goodwizard/memory/procedural.ex` that accepts `memory_dir` and `opts` (keyword with `decay_days` default 60, `archive_days` default 120)
- [ ] 2.2 Implement decay logic: scan all procedures, find those with `last_used` older than `decay_days` (or nil), demote confidence (high to medium, medium to low)
- [ ] 2.3 Implement archival/deletion logic: delete procedures at `confidence: "low"` with `last_used` older than `archive_days` (or nil and `created_at` older than `archive_days`)
- [ ] 2.4 Create `lib/goodwizard/actions/memory/procedural/decay_unused.ex` with `DecayUnusedProcedures` action wrapping the `decay_unused/2` function
- [ ] 2.5 Return result with counts: procedures demoted, procedures deleted, procedures unchanged

## 3. Cross-Type Consolidation Action

- [ ] 3.1 Create `lib/goodwizard/actions/memory/cross_consolidate.ex` with `CrossConsolidate` action using `Jido.Action` with schema params: `episode_limit` (integer, default 20), `min_episodes` (integer, default 5)
- [ ] 3.2 Load recent successful episodes (frontmatter + body) via `Memory.Episodic.list/2` with `outcome: "success"` filter
- [ ] 3.3 Skip cross-consolidation if fewer than `min_episodes` successful episodes exist
- [ ] 3.4 Load all existing procedure summaries (frontmatter only) via `Memory.Procedural.list/2` for deduplication context
- [ ] 3.5 Build LLM prompt that includes episode details and existing procedure summaries, asking for pattern detection and new procedure suggestions
- [ ] 3.6 Parse LLM JSON response as an array of procedure definitions with fields: `type`, `summary`, `tags`, `when_to_apply`, `steps`, `notes`
- [ ] 3.7 Create each suggested procedure via `Memory.Procedural.create/3` with `source: "inferred"` and `confidence: "low"`
- [ ] 3.8 Return result with count of procedures created and their summaries

## 4. Register Actions

- [ ] 4.1 Add `ArchiveOldEpisodes`, `DecayUnusedProcedures`, and `CrossConsolidate` to the agent's tool list in `lib/goodwizard/plugins/tools.ex`

## 5. Tests -- Episodic Archival

- [ ] 5.1 Add test: archival skips when episodic file count is at or below threshold
- [ ] 5.2 Add test: archival keeps all episodes from the last 30 days regardless of outcome
- [ ] 5.3 Add test: archival keeps successful episodes from the last 90 days
- [ ] 5.4 Add test: archival consolidates older episodes into monthly summary entries
- [ ] 5.5 Add test: monthly summary includes aggregated type and outcome counts
- [ ] 5.6 Add test: monthly summary includes key lessons from archived episodes
- [ ] 5.7 Add test: individual archived episodes are deleted after summary creation
- [ ] 5.8 Add test: archival is idempotent (running twice does not create duplicate summaries)

## 6. Tests -- Procedural Confidence Decay

- [ ] 6.1 Add test: procedures used within `decay_days` are not demoted
- [ ] 6.2 Add test: high-confidence procedure unused for 60+ days is demoted to medium
- [ ] 6.3 Add test: medium-confidence procedure unused for 60+ days is demoted to low
- [ ] 6.4 Add test: low-confidence procedure unused for 120+ days is deleted
- [ ] 6.5 Add test: procedure with nil `last_used` and `created_at` older than thresholds is handled correctly
- [ ] 6.6 Add test: decay is idempotent (running twice in succession does not double-demote)

## 7. Tests -- Cross-Type Consolidation

- [ ] 7.1 Add test: cross-consolidation skips when fewer than `min_episodes` successful episodes exist
- [ ] 7.2 Add test: cross-consolidation creates procedures with `source: "inferred"` and `confidence: "low"`
- [ ] 7.3 Add test: existing procedure summaries are included in the LLM prompt
- [ ] 7.4 Add test: LLM response with no suggested procedures results in no new files
- [ ] 7.5 Add test: created procedures have valid frontmatter and body structure
