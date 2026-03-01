## 1. Config & Workspace Setup

- [ ] 1.1 Add `openspec` config section to `Config` module (`@defaults`, `config.toml`, `setup.ex`) with `workspace` sub-path defaulting to `"openspec"`
- [ ] 1.2 Add `Config.openspec_dir/0` helper that returns the resolved openspec workspace path
- [ ] 1.3 Add `openspec/` to `ensure_workspace/1` directory creation list
- [ ] 1.4 Update preamble to reference the `openspec/` workspace directory

## 2. Spec Parser

- [ ] 2.1 Create `Goodwizard.OpenSpec.Parser` module that extracts requirements and scenarios from spec markdown files using pattern matching on `### Requirement:` and `#### Scenario:` headers
- [ ] 2.2 Add RFC 2119 keyword detection (SHALL, MUST, SHOULD, MAY) with counts per requirement
- [ ] 2.3 Add path safety validation (reject `..`, null bytes, leading `/`) matching `Brain.Paths` patterns
- [ ] 2.4 Write tests for parser covering well-formed specs, empty files, and malformed content

## 3. Plugin

- [ ] 3.1 Create `Goodwizard.Plugins.OpenSpec` plugin with `mount/2` that scans `workspace/openspec/` and builds project→capability→requirement index
- [ ] 3.2 Implement index data structure: `%{project_name => %{capability_name => %{requirements: count, scenarios: count, file_path: path}}}`
- [ ] 3.3 Implement system prompt summary generation (compact project listing with capability names and requirement counts)
- [ ] 3.4 Register plugin in agent setup (add to plugin list in agent configuration)
- [ ] 3.5 Write tests for plugin mount with specs present, no directory, and empty projects

## 4. Actions — Discovery

- [ ] 4.1 Create `Goodwizard.Actions.OpenSpec.ListProjects` action returning project names with capability counts
- [ ] 4.2 Create `Goodwizard.Actions.OpenSpec.ListSpecs` action accepting `project` param, returning capabilities with requirement counts
- [ ] 4.3 Create `Goodwizard.Actions.OpenSpec.ListChanges` action accepting `project` param, returning change names with artifact status
- [ ] 4.4 Write tests for discovery actions

## 5. Actions — Management

- [ ] 5.1 Create `Goodwizard.Actions.OpenSpec.ReadSpec` action accepting `project` and `capability` params, returning full spec markdown content
- [ ] 5.2 Create `Goodwizard.Actions.OpenSpec.ReadChangeArtifact` action accepting `project`, `change`, `artifact` (and optional `capability` for delta specs)
- [ ] 5.3 Create `Goodwizard.Actions.OpenSpec.SearchSpecs` action accepting `query` and optional `project` filter, returning matching lines with file paths
- [ ] 5.4 Write tests for management actions including path traversal rejection

## 6. Prompt Skill

- [ ] 6.1 Create `priv/workspace/skills/openspec/SKILL.md` with frontmatter (name, description) and body documenting OpenSpec concepts, available actions, and usage guidance
- [ ] 6.2 Verify skill appears in PromptSkills scan and can be activated

## 7. Integration Testing

- [ ] 7.1 Write integration test with a fixture workspace containing multiple projects with specs and changes, verifying end-to-end flow: plugin mount → list projects → read spec → search specs
