## 1. Memory.Entry Module

- [ ] 1.1 Create `lib/goodwizard/memory/entry.ex` with `parse/1` — split content on `---` fences, reject YAML anchors, enforce 64 KB frontmatter limit and 1 MB body limit, decode YAML frontmatter into a string-keyed map, return `{:ok, {map, body_string}}` or `{:error, reason}`
- [ ] 1.2 Add `serialize/2` to `Memory.Entry` — encode a frontmatter map as YAML, wrap in `---` fences, append body string. Handle string quoting, list values, and nil/boolean/integer values
- [ ] 1.3 Write unit tests in `test/goodwizard/memory/entry_test.exs` covering: parse/serialize roundtrip, missing frontmatter error, empty body, oversized frontmatter rejection, oversized body rejection, YAML anchor rejection, special YAML characters in values, string keys in output, nil and boolean values

## 2. Memory.Paths Updates

- [ ] 2.1 Add `episodic_dir/1` and `procedural_dir/1` functions to `lib/goodwizard/memory/paths.ex` that return the path to the respective subdirectory
- [ ] 2.2 Add `episode_path/2` and `procedure_path/2` functions that return the full path to a specific entry file by ID (appending `.md` extension)
- [ ] 2.3 Add `validate_memory_subdir/2` that accepts a memory directory and a subdirectory name, validates the name is in the allowed set (`episodic`, `procedural`), and returns `{:ok, path}` or `{:error, :invalid_subdir}`
- [ ] 2.4 Write unit tests in `test/goodwizard/memory/paths_test.exs` covering: episodic/procedural path construction, episode/procedure file paths, valid and invalid subdirectory validation, path traversal rejection in subdirectory names

## 3. Verification

- [ ] 3.1 Run `mix compile --warnings-as-errors`
- [ ] 3.2 Run `mix format --check-formatted`
- [ ] 3.3 Run `mix test` and verify no new failures
