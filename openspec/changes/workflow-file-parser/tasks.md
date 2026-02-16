## 1. YAML Loader

- [ ] 1.1 Create `lib/goodwizard/workflow/workflow_file.ex` with `parse_file/2` that reads a file path and decodes YAML via `YamlElixir.read_from_file/1`
- [ ] 1.2 Wrap YAML parse errors in `{:error, {:yaml_parse_error, message}}`
- [ ] 1.3 Handle file-not-found with `{:error, {:file_not_found, path}}`

## 2. Field Validation

- [ ] 2.1 Validate required top-level fields: `name` (string) and `steps` (list)
- [ ] 2.2 Validate optional fields: `args` (map), `env` (map), `timeout` (integer), `description` (string)
- [ ] 2.3 Return tagged error tuples for missing/invalid fields

## 3. Step Parser

- [ ] 3.1 Parse each step's `id`, `command`, `stdin`, `approval`, `condition`/`when` fields
- [ ] 3.2 Validate step `id` uniqueness and format (`^[a-zA-Z0-9_-]+$`)
- [ ] 3.3 Map `approval: true` steps to type `:approve`, others to `:exec`
- [ ] 3.4 Error on missing `id` or `command` fields per step

## 4. Reference Resolver

- [ ] 4.1 Parse `$step_id.stdout` and `$step_id.json` patterns from `stdin` fields
- [ ] 4.2 Validate references point to preceding steps (reject forward references)
- [ ] 4.3 Validate referenced step ids exist in the workflow
- [ ] 4.4 Build `depends_on` list on each Step struct

## 5. Args Merger

- [ ] 5.1 Implement args default loading from YAML `args` map
- [ ] 5.2 Shallow-merge runtime `args_override` opts on top of defaults
- [ ] 5.3 Interpolate `${arg_name}` patterns in step commands with merged values

## 6. Pipeline Assembly

- [ ] 6.1 Assemble validated steps into a `%Pipeline{}` struct with name, timeout_ms, max_stdout_bytes from YAML fields

## 7. Tests

- [ ] 7.1 Tests for valid workflow file parsing end-to-end
- [ ] 7.2 Tests for validation errors: missing name, missing steps, invalid YAML, non-existent file
- [ ] 7.3 Tests for step parsing: id uniqueness, approval detection, missing fields
- [ ] 7.4 Tests for reference resolution: valid refs, forward refs, non-existent refs
- [ ] 7.5 Tests for args merging: defaults, overrides, interpolation
