# Keep a Changelog Format Reference

Based on https://keepachangelog.com/en/1.1.0/

## File Structure

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-03-01

### Added
- New feature description

### Changed
- Modified behavior description

### Deprecated
- Feature marked for removal

### Removed
- Removed feature description

### Fixed
- Bug fix description

### Security
- Security fix description

## [1.1.0] - 2026-02-15

### Added
- Previous feature

[Unreleased]: https://github.com/user/repo/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/user/repo/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/user/repo/releases/tag/v1.1.0
```

## Section Order

Always use this order (omit empty sections):
1. Added — new features
2. Changed — changes in existing functionality
3. Deprecated — soon-to-be removed features
4. Removed — removed features
5. Fixed — bug fixes
6. Security — vulnerability fixes

## Conventional Commit Mapping

| Commit Prefix | Changelog Section |
|---|---|
| `feat:` / `feat(scope):` | Added |
| `fix:` / `fix(scope):` | Fixed |
| `perf:` | Changed |
| `refactor:` | Changed (only if user-visible) |
| `deps:` / `build:` | Changed |
| `security:` | Security |
| `BREAKING CHANGE:` footer or `!` after type | separate **BREAKING** callout at top of section |
| `docs:`, `test:`, `ci:`, `chore:`, `style:` | Omit (not user-facing) |

## Rules

- Dates use ISO 8601 format: YYYY-MM-DD
- Versions use semantic versioning: MAJOR.MINOR.PATCH
- Most recent version comes first (reverse chronological)
- Each version gets its own `## [x.y.z]` heading
- `[Unreleased]` section at top collects changes not yet in a release
- Comparison links at bottom of file (GitHub/GitLab format)
- Write entries for humans, not machines — describe the impact, not the implementation
