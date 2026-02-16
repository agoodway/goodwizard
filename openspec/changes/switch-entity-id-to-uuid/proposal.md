## Why

Brain entity IDs are currently generated using Sqids with a file-based monotonic counter (`brain/.counter`). This requires file locking, counter recovery logic, stale lock cleanup, and the `sqids` dependency — all complexity for generating short IDs in a local file-backed store that doesn't need sequential or compact identifiers. UUIDv7 is simpler (no shared state, no locking, no counter file), universally understood, and collision-free without coordination. Unlike UUIDv4, UUIDv7 embeds a millisecond-precision timestamp in the first 48 bits, making IDs naturally time-ordered — entities sort chronologically by ID, which is valuable for sync between agents/apps and for human-readable file listings.

## What Changes

- **BREAKING**: Entity ID format changes from sqids (`[a-z0-9]{8,64}`) to UUIDv7 (`xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx`)
- **BREAKING**: All cross-entity reference patterns in schemas change to match UUID format
- **BREAKING**: Entity filenames change from `<sqid>.md` to `<uuid>.md`
- Replace `Goodwizard.Brain.Id` internals: remove Sqids encoding, counter file, file locking, counter recovery — replace with `Uniq.UUID.uuid7()` (via `uniq` hex package)
- Update `id_pattern/0` and `valid?/1` to match UUID format
- Update all schema patterns in `Goodwizard.Brain.Seeds` for ID fields and entity references
- Replace `sqids` dependency with `uniq` in `mix.exs`
- Remove `brain/.counter` and `brain/.counter.lock` file handling from `Goodwizard.Brain.Paths` (if referenced there)
- Existing entities with sqids IDs will not validate against new schemas (clean break)

## Capabilities

### New Capabilities

- `uuid-entity-ids`: UUIDv7 generation and validation for brain entity IDs, replacing sqids

### Modified Capabilities

_None_ — no existing specs to modify.

## Impact

- **Code**: `Goodwizard.Brain.Id` (rewrite), `Goodwizard.Brain.Seeds` (pattern updates to `base_properties`, `entity_ref`, `entity_ref_list`, `notes` polymorphic ref), `Goodwizard.Brain.Paths` (remove counter path if present)
- **Dependencies**: Replace `sqids` with `uniq` in `mix.exs`
- **Schemas**: All 7 seed schema JSON files need regeneration with UUID patterns
- **Data**: Existing entities with sqids IDs will not pass validation. Users start fresh or manually rename files and update references.
- **Tests**: All ID-related tests need updated format expectations
