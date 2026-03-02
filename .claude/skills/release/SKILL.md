---
name: release
description: >-
  Manage semantic versioning, changelogs, and git tags for releases. Supports Elixir/Mix
  (mix.exs), Node (package.json), and generic (VERSION file) projects. Use when the user
  says '/release bump', '/release changelog', '/release tag', '/release', 'bump version',
  'create release', 'update changelog', 'tag release', 'prepare release', 'what version',
  or needs help with semantic versioning and release management.
---

# Release

Manage semantic versioning and Keep a Changelog formatted release notes.

## Commands

- **`/release bump <level>`** — Bump the version (major, minor, patch)
- **`/release changelog`** — Generate or update CHANGELOG.md
- **`/release tag`** — Create a git tag for the current version
- **`/release`** (no subcommand) — Show current version and unreleased changes

## `/release bump`

Bump the project version following semver.

**Input**: `/release bump <major|minor|patch>` or just `/release bump` to be asked.

**Steps**:

1. Detect project type and locate the version source:
   - `mix.exs` → look for `version: "x.y.z"` in `project/0`
   - `package.json` → look for `"version": "x.y.z"`
   - `VERSION` file → plain `x.y.z` string
   - If multiple exist, prefer `mix.exs` > `package.json` > `VERSION`

2. If no level argument provided, ask using AskUserQuestion:
   - Show current version
   - Offer major/minor/patch with descriptions of what each means

3. Calculate the new version per semver:
   - **major**: increment major, reset minor and patch to 0
   - **minor**: increment minor, reset patch to 0
   - **patch**: increment patch

4. Update the version in the source file using Edit tool

5. Report: `Version bumped: x.y.z → x.y.z`

**Do NOT** commit, tag, or modify CHANGELOG.md — those are separate commands.

## `/release changelog`

Generate or update CHANGELOG.md using Keep a Changelog format.
See [references/keepachangelog.md](references/keepachangelog.md) for format details.

**Input**: `/release changelog` or `/release changelog "manual description of changes"`

**Steps**:

1. Read the current version from the version source (same detection as bump)

2. Read existing `CHANGELOG.md` if present. If not, create one with the header:
   ```markdown
   # Changelog

   All notable changes to this project will be documented in this file.

   The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
   and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
   ```

3. Gather changes — use BOTH sources, merging results:

   a. **Git commits**: Find the last version tag (`vX.Y.Z` or `X.Y.Z` format):
      ```bash
      git tag --sort=-v:refname | head -20
      ```
      Then get commits since that tag:
      ```bash
      git log <last-tag>..HEAD --pretty=format:"%s" --no-merges
      ```
      If no tags exist, use all commits.

   b. **Manual input**: If the user provided a description argument, incorporate it.
      If git history is empty or unclear, ask the user to describe changes.

4. Categorize entries using conventional commit prefixes (see reference file for mapping).
   For non-conventional commits, use best judgment to categorize, or ask the user.

5. Write the changelog entry:
   - If an `[Unreleased]` section exists with content, move its entries into the new version section
   - Insert the new `## [x.y.z] - YYYY-MM-DD` section after `[Unreleased]`
   - Add/update comparison links at the bottom of the file
   - Omit empty sections (don't add `### Removed` if nothing was removed)

6. Detect the git remote to format comparison links:
   ```bash
   git remote get-url origin
   ```
   Generate GitHub/GitLab style links. If no remote, omit links.

7. Show the user the generated entry for review before writing.

## `/release tag`

Create an annotated git tag for the current version.

**Steps**:

1. Read the current version from the version source

2. Check that the working tree is clean:
   ```bash
   git status --porcelain
   ```
   If dirty, warn the user and ask whether to proceed

3. Check that the tag doesn't already exist:
   ```bash
   git tag -l "vX.Y.Z"
   ```
   If it exists, inform the user and stop

4. Extract the current version's changelog entry from CHANGELOG.md for the tag message.
   If no changelog entry exists, use a simple message.

5. Create the annotated tag:
   ```bash
   git tag -a "vX.Y.Z" -m "<changelog entry or version string>"
   ```

6. Report the created tag. Ask before pushing:
   ```bash
   git push origin "vX.Y.Z"
   ```

**Do NOT** push without explicit user confirmation.

## `/release` (no subcommand)

Show release status: current version, last tag, and unreleased changes.

**Steps**:

1. Read current version from version source
2. Find the latest git tag: `git tag --sort=-v:refname | head -1`
3. Count commits since last tag: `git rev-list <tag>..HEAD --count`
4. Show a brief summary of unreleased commits grouped by type
5. If `[Unreleased]` section exists in CHANGELOG.md, show its contents

## Guardrails

- Never modify version files without the user invoking `/release bump`
- Never push tags without explicit user confirmation
- Never delete or overwrite existing changelog entries — only add new ones
- Preserve all existing content and formatting in CHANGELOG.md
- Use `v` prefix for git tags (e.g., `v1.2.3`) — this is the most common convention
- Dates in changelog always use ISO 8601 (YYYY-MM-DD)
