## 1. Core Module

- [ ] 1.1 Create `lib/goodwizard/actions/filesystem/grep_file.ex` with `use Jido.Action`, schema (`path`, `pattern`, `case_sensitive`, `recursive`, `context_lines`, `file_glob`, `max_results`), and stub `run/2`
- [ ] 1.2 Implement backend detection — check for `rg` via `System.find_executable/1`, fall back to `grep`, error if neither available
- [ ] 1.3 Implement argument builder for ripgrep backend — map schema params to `rg` CLI flags (`-i`, `-r`, `-C`, `--glob`, `-m`, `--no-heading`, `--line-number`)
- [ ] 1.4 Implement argument builder for grep backend — map schema params to `grep` CLI flags (`-i`, `-r`, `-C`, `--include`, `-m`, `-n`, `-H`)
- [ ] 1.5 Implement `run/2` — resolve path via `Filesystem.resolve_path/1`, detect backend, build args, execute via `System.cmd/3`, parse and format output
- [ ] 1.6 Implement result truncation — cap at `max_results` lines and 10,000 characters with summary messages

## 2. Agent Registration

- [ ] 2.1 Add `Goodwizard.Actions.Filesystem.GrepFile` to the `tools:` list in `Goodwizard.Agent`

## 3. Tests

- [ ] 3.1 Create `test/goodwizard/actions/filesystem/grep_file_test.exs` with temp dir setup/teardown
- [ ] 3.2 Test: pattern found in a single file returns `{:ok, %{matches: ..., match_count: N}}`
- [ ] 3.3 Test: recursive directory search finds matches across files
- [ ] 3.4 Test: no matches returns `{:ok, %{matches: "No matches found.", match_count: 0}}`
- [ ] 3.5 Test: path does not exist returns `{:error, "Path not found: <path>"}`
- [ ] 3.6 Test: case-insensitive search with `case_sensitive: false`
- [ ] 3.7 Test: context lines included when `context_lines` > 0
- [ ] 3.8 Test: file glob filtering limits searched files
- [ ] 3.9 Test: result truncation when matches exceed `max_results`
- [ ] 3.10 Test: workspace restriction returns error for paths outside workspace
