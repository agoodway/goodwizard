# Phase 2: Actions — Tasks

## Backend

- [ ] 1.1 Create Goodwizard.Actions.Filesystem.ReadFile action (schema + run/2 with ~ expansion, allowed_dir, error handling)
- [ ] 1.2 Create Goodwizard.Actions.Filesystem.WriteFile action (create parent dirs, write UTF-8, return byte count)
- [ ] 1.3 Create Goodwizard.Actions.Filesystem.EditFile action (find-and-replace, not-found error, ambiguous warning, first occurrence only)
- [ ] 1.4 Create Goodwizard.Actions.Filesystem.ListDir action (sorted entries, [DIR]/[FILE] prefixes, error handling)
- [ ] 1.5 Create Goodwizard.Actions.Shell.Exec action (safety guards, timeout, stdout+stderr capture, output truncation)

## Test

- [ ] 2.1 Test ReadFile: read existing file, missing file, non-file path
- [ ] 2.2 Test WriteFile: create new file, create with parent dirs, overwrite existing
- [ ] 2.3 Test EditFile: successful replace, old_text not found, ambiguous match warning
- [ ] 2.4 Test ListDir: list files with prefixes, empty dir, not a directory
- [ ] 2.5 Test Exec: simple command, timeout, blocked command (rm -rf), workspace restriction
