## Context

The brain knowledge base stores people and companies as markdown files with YAML frontmatter, validated against JSON Schema definitions in `priv/workspace/brain/schemas/`. Currently:

- `people.json` has scalar `email` (string, format:email) and `phone` (string) fields
- `companies.json` has a scalar `location` (string) field and `domain` (string)
- Neither entity type has address or social media fields
- `SchemaMapper` converts JSON Schema properties to NimbleOptions types for Jido Action params — it handles `array` of `string` but not `array` of `object`
- `ToolGenerator` generates runtime `Create*`/`Update*` action modules from schemas
- `Entity` serializes/parses YAML frontmatter — currently handles flat scalars, arrays of strings, and maps

## Goals / Non-Goals

**Goals:**

- People and companies support multiple phones, emails, addresses, and socials as arrays of typed objects
- Each entry carries a `type` label (e.g., "work", "mobile", "personal") and a `value`
- Address entries carry structured sub-fields (street, city, state, zip, country) instead of a single value
- SchemaMapper correctly maps array-of-object properties to a Jido-compatible type
- Generated tools accept structured contact data through the normal create/update flows
- Existing entity data with old scalar fields is migrated to the new array format
- Entity YAML serialization round-trips arrays of objects correctly

**Non-Goals:**

- No deduplication or uniqueness enforcement across contact field entries
- No "primary" flag or default selection within a contact field array
- No validation of phone number formats, social media URL patterns, or address completeness
- No UI/channel changes — this is schema and brain layer only
- No new entity types (contacts remain embedded fields, not separate entities)

## Decisions

### 1. Contact fields as arrays of objects with `type`/`value` shape

Each contact field (phones, emails, socials) uses a consistent shape:

```json
{
  "type": "array",
  "items": {
    "type": "object",
    "properties": {
      "type": { "type": "string" },
      "value": { "type": "string" }
    },
    "required": ["value"]
  }
}
```

`type` is optional with sensible defaults inferred by context (e.g., omitting type on a phone means "phone" generically).

**Why over alternatives:**
- *Flat strings with conventions* (e.g., `"mobile:+1234567890"`) — fragile parsing, no validation, bad UX for the LLM
- *Separate entity type* (e.g., `contact_methods/`) — over-engineering for embedded data, adds reference management complexity
- *Map keyed by type* (e.g., `{"work": "+1234567890"}`) — prevents multiple entries of the same type (two work phones)

### 2. Addresses use structured sub-fields instead of `type`/`value`

Addresses need more structure than a single `value` string:

```json
{
  "type": "array",
  "items": {
    "type": "object",
    "properties": {
      "type": { "type": "string" },
      "street": { "type": "string" },
      "city": { "type": "string" },
      "state": { "type": "string" },
      "zip": { "type": "string" },
      "country": { "type": "string" }
    }
  }
}
```

No fields are required within an address object — partial addresses (city-only, country-only) are valid.

**Why:** A single `value` string for addresses is hard to parse and useless for structured queries. Separate fields let the LLM populate what it knows without guessing formatting.

### 3. SchemaMapper maps array-of-object to `{:list, :map}`

Add a new clause in `SchemaMapper.map_type/1`:

```elixir
defp map_type(%{"type" => "array", "items" => %{"type" => "object"}}) do
  {:list, :map}
end
```

This tells Jido the param accepts a list of maps. The JSON Schema validation layer (ex_json_schema) handles the detailed object shape validation — SchemaMapper only needs to get the NimbleOptions type right.

**Why over `:list, :any`:** More descriptive for tool documentation. The LLM sees `list of maps` rather than `list of any`, giving it better guidance.

### 4. Rename fields with version bump, not aliasing

The schemas use a `"version"` field. Bump from `1` to `2` on both people and companies schemas. Remove the old field names (`email`, `phone`, `location`) entirely — no aliasing or backwards-compatible shims.

**Why:** The brain is file-backed with no external consumers. A clean rename is simpler than maintaining aliases. Migration handles existing data.

### 5. Migration via a one-time Mix task

Create `mix goodwizard.migrate_contacts` that:
1. Scans all entity files in `brain/people/` and `brain/companies/`
2. For each entity with old scalar fields, converts to the new array format
3. Removes the old field, writes the updated file
4. Reports what was migrated

**Why over automatic migration:** Explicit and reversible. Users can review before running. Doesn't complicate the normal read/write path.

### 6. Entity YAML serialization already handles nested structures

`Entity.encode_yaml_value/1` already recurses into maps and lists. Arrays of objects will serialize as inline YAML (e.g., `[{type: work, value: foo@bar.com}]`). No changes needed to `Entity.serialize/2` or `Entity.parse/1` — YamlElixir handles nested structures on parse.

Verify this assumption in implementation by testing round-trip with arrays of objects.

## Risks / Trade-offs

- **YAML readability degrades with nested objects** → Inline YAML for arrays of objects is harder to read in raw files. Acceptable since entities are primarily accessed through the agent, not edited by hand. If readability becomes an issue, block-style YAML serialization can be added later.

- **Breaking change for existing entities** → Migration task must run before entities with old fields pass validation. Mitigated by the Mix task and schema version bump — validation errors on old entities will clearly indicate migration is needed.

- **Generated tool parameter complexity increases** → LLM now needs to pass `[%{type: "work", value: "..."}]` instead of a flat string. Mitigated by clear parameter documentation in the generated tool descriptions.

- **No partial-update semantics for array items** → Updating a single phone in the array requires passing the full array. This is consistent with how other array fields (tags, notes) already work in the brain.
