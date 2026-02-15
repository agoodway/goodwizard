## Why

Brain entity IDs are currently generated using Sqids with a file-based monotonic counter (`brain/.counter`). This requires file locking, counter recovery logic, stale lock cleanup, and the `sqids` dependency — all complexity for generating short IDs in a local file-backed store that doesn't need sequential or compact identifiers. UUID v4 is simpler (no shared state, no locking, no counter file), universally understood, and collision-free without coordination.

## What Changes

- **BREAKING**: Entity ID format changes from sqids (`[a-z0-9]{8,64}`) to UUID v4 (`xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`)
- **BREAKING**: All cross-entity reference patterns in schemas change to match UUID format
- **BREAKING**: Entity filenames change from `<sqid>.md` to `<uuid>.md`
- Replace `Goodwizard.Brain.Id` internals: remove Sqids encoding, counter file, file locking, counter recovery — replace with `UUID.uuid4()` (Elixir stdlib)
- Update `id_pattern/0` and `valid?/1` to match UUID format
- Update all schema patterns in `Goodwizard.Brain.Seeds` for ID fields and entity references
- Remove `sqids` dependency from `mix.exs`
- Remove `brain/.counter` and `brain/.counter.lock` file handling from `Goodwizard.Brain.Paths` (if referenced there)
- Existing entities with sqids IDs will not validate against new schemas (clean break)

## Capabilities

### New Capabilities

- `uuid-entity-ids`: UUID v4 generation and validation for brain entity IDs, replacing sqids

### Modified Capabilities

_None_ — no existing specs to modify.

## Impact

- **Code**: `Goodwizard.Brain.Id` (rewrite), `Goodwizard.Brain.Seeds` (pattern updates to `base_properties`, `entity_ref`, `entity_ref_list`, `notes` polymorphic ref), `Goodwizard.Brain.Paths` (remove counter path if present)
- **Dependencies**: Remove `sqids` from `mix.exs`
- **Schemas**: All 7 seed schema JSON files need regeneration with UUID patterns
- **Data**: Existing entities with sqids IDs will not pass validation. Users start fresh or manually rename files and update references.
- **Tests**: All ID-related tests need updated format expectations
