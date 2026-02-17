## 1. Memory Seeds Module

- [ ] 1.1 Create `lib/goodwizard/memory/seeds.ex` with `Goodwizard.Memory.Seeds` module implementing `seed/1` that takes a workspace path
- [ ] 1.2 Implement directory creation for `memory/episodic/` and `memory/procedural/` using `File.mkdir_p!/1`
- [ ] 1.3 Implement `MEMORY.md` creation only when the file does not already exist (write empty string)
- [ ] 1.4 Return `:ok` on success

## 2. Setup Task Integration

- [ ] 2.1 Update `lib/mix/tasks/goodwizard.setup.ex` to call `Goodwizard.Memory.Seeds.seed/1` after existing subdirectory creation
- [ ] 2.2 Add `memory/episodic` and `memory/procedural` to the setup output messages

## 3. Preamble Update

- [ ] 3.1 Update `lib/goodwizard/character/preamble.ex` `@preamble` to replace the `memory/` line with a "Memory System" subsection describing semantic, episodic, and procedural memory types
- [ ] 3.2 Include storage locations (`brain/`, `memory/MEMORY.md`, `memory/episodic/`, `memory/procedural/`) and behavioral guidance for each type
- [ ] 3.3 Verify the updated preamble stays under the 10KB compile-time limit

## 4. Tests

- [ ] 4.1 Create `test/goodwizard/memory/seeds_test.exs` testing that `seed/1` creates both subdirectories
- [ ] 4.2 Add test for idempotency: calling `seed/1` twice does not error or overwrite existing MEMORY.md content
- [ ] 4.3 Add test that `seed/1` preserves existing MEMORY.md content when file already exists
- [ ] 4.4 Update `test/goodwizard/character/preamble_test.exs` to assert preamble contains "Semantic Memory", "Episodic Memory", and "Procedural Memory" descriptions
- [ ] 4.5 Update preamble test assertions to match the new memory directory descriptions (`memory/episodic/`, `memory/procedural/`)
