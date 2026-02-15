## Context

The brain knowledge base stores entities as markdown files with YAML frontmatter, validated against JSON Schema definitions. Eight entity types ship by default (people, places, events, notes, tasks, companies, tasklists), defined in `Goodwizard.Brain.Seeds`. The CRUD operations in `Goodwizard.Brain` are generic — they work with any entity type that has a schema. All entities share base properties (id, name, notes, tags, created_at, updated_at) defined in `base_properties/0`, which are merged into every schema via `build_schema/3`.

## Goals / Non-Goals

**Goals:**
- Add a `webpages` entity type for storing URLs with metadata (title, url, description)
- Make webpages referenceable from all other entity types via a `webpages` field in base properties
- Exclude the `webpages` field from the webpages schema itself (no self-references)
- Maintain the same CRUD patterns used by all other entity types

**Non-Goals:**
- No URL validation beyond JSON Schema `format: uri` (no HTTP fetching or link checking)
- No cascading operations (deleting a webpage does not remove references from other entities)
- No automatic metadata extraction (scraping page titles, favicons, etc.)
- No UI or channel-specific behavior

## Decisions

**Schema field design**: The `webpages` schema will have `title` (required), `url` (required, format: uri), and `description` (optional). This keeps the entity minimal — the markdown body can hold extended notes or content snapshots.

**Base property integration**: Add `"webpages" => entity_ref_list("webpages")` to `base_properties/0`. Since `build_schema/3` merges custom properties on top of base properties, the webpages schema needs to explicitly exclude the self-referencing field by overriding it. The cleanest approach: build the webpages schema with a custom `build_schema` call that drops the `webpages` key from the merged properties, or override it in the custom properties map with a delete. We'll use `Map.delete/2` on the merged result — add a `build_schema_without/4` helper or handle it in `schema_for("webpages")` by building manually. Simplest: use `build_schema/3` and then `Map.update!/3` to remove the field from properties, keeping the change minimal.

**Naming: `webpages` not `web_pages` or `urls`**: All existing entity types use single lowercase words or compound words without underscores (people, places, events, tasklists). `webpages` follows this convention. The name `urls` was considered but `webpages` better describes the entity as a resource with metadata, not just a bare URL.

**No schema migration**: Since the brain has no existing `webpages` data, this is purely additive. `Seeds.seed/1` only writes schemas that don't already exist. Existing entity schemas on disk won't automatically gain the `webpages` field — but new workspaces will. Existing workspaces get updated schemas when re-seeded or schemas are manually refreshed.

## Risks / Trade-offs

**Existing schemas on disk won't auto-update** — Adding `webpages` to base properties changes the in-memory schema, but existing workspace schema files on disk won't include the new field until re-seeded. The JSON Schema validation uses the on-disk schema, so existing entities won't be able to use the `webpages` field until their schema files are regenerated. → This is consistent with how schema changes have worked for other additions. A future schema migration system could address this.

**Self-reference exclusion adds complexity** — Removing the `webpages` field from the webpages schema itself breaks the uniform `build_schema/3` pattern slightly. → The impact is minimal (one extra line in `schema_for("webpages")`) and the alternative (allowing self-references) would be semantically confusing.
