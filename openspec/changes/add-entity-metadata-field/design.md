## Context

Brain entities are stored as markdown files with YAML frontmatter, validated against JSON Schema definitions. All entity types share a set of base properties defined in `Goodwizard.Brain.Seeds.base_properties/0`: `id`, `name`, `notes`, `tags`, `created_at`, `updated_at`. Schemas set `additionalProperties: false`, so any new field must be explicitly declared.

System fields (`@system_fields` in `Goodwizard.Brain`) are currently `["id", "created_at", "updated_at"]`. These are stripped from user input on create and set by the system. On update, they are stripped from new data to prevent override.

There is currently no generic extensibility mechanism — storing arbitrary context (source system, import batch, external URLs) requires adding type-specific schema fields.

## Goals / Non-Goals

**Goals:**
- Add a **required** `metadata` field to the shared base properties so every entity type inherits it
- Define it as a JSON object with string keys and string values
- Auto-initialize to `%{}` on create if not provided by the caller
- Protect from removal — metadata is always present on every entity
- Allow callers to set and update metadata values freely

**Non-Goals:**
- No nested/complex value types — values are strings only
- No indexing or querying by metadata keys
- No automatic metadata population by the system (actions may set metadata, but it's not automatic)
- No migration tool for existing entity files

## Decisions

**1. JSON Schema type: `object` with `additionalProperties` of type `string`**

The metadata field uses JSON Schema's `additionalProperties` to allow arbitrary string keys with string values. This is the simplest schema that enforces the key-value-string constraint without requiring a predefined set of keys.

Alternative considered: `array` of `{key, value}` objects — rejected as more verbose for both schema definition and usage, with no benefit for a simple key-value store.

**2. Add to `base_properties/0` and `required` list**

Since metadata applies to all entity types, it belongs in the shared base. The `build_schema/3` function currently takes a `required` list per type. To make metadata universally required, `build_schema/3` will append `"metadata"` to the required list for every schema.

**3. System-protected field with special handling**

Unlike `id`/`created_at`/`updated_at` which are fully system-controlled, `metadata` is a hybrid: the system guarantees its presence but callers control its contents.

Implementation approach in `Goodwizard.Brain`:
- **Create path** (`do_create/4`): After dropping system fields and merging system values, also merge `metadata`. If the caller provided metadata, use it; otherwise default to `%{}`. The key line: `Map.put_new(data, "metadata", %{})` applied after the system field merge.
- **Update path** (`locked_update/5`): The existing `Map.merge(existing_data, safe_data)` already preserves `metadata` from the existing entity when the update doesn't include it. Add `"metadata"` to the fields protected from being set to `nil` — if update data has `"metadata" => nil`, drop it before merge.

Adding `"metadata"` to `@system_fields` would cause it to be stripped on create (breaking caller-provided metadata). Instead, handle it separately: protect from removal but allow setting.

**4. Strip metadata from action results**

Brain actions (`ReadEntity`, `ListEntities`) return entity data maps that flow into the agent's prompt context. The `metadata` field is for system/integration use only — it must never appear in messages or prompts sent to the LLM. Both actions will `Map.drop(data, ["metadata"])` before returning results.

**5. Add to `build_schema/3` required list automatically**

`build_schema/3` will always include `"metadata"` in the required array alongside whatever the type specifies. This ensures even custom schemas get the requirement without the caller remembering to add it.

## Risks / Trade-offs

**[Existing entities without metadata fail validation]** → Acceptable trade-off for data consistency. Existing entities will need `metadata: {}` added to their frontmatter. This is a simple find-and-add operation.

**[Existing schema files won't include metadata until re-seeded]** → `Seeds.seed/1` only writes schemas that don't exist. Users must delete and re-seed, or manually update their schema JSON files.

**[String-only values limit flexibility]** → Intentional. String values keep the schema simple. Callers can JSON-encode complex values into strings if needed.
