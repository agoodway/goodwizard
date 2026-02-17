## Why

People and companies often have multiple phone numbers, email addresses, physical addresses, and social media profiles. The current brain schemas only support a single `email` and `phone` on people, a single `location` on companies, and neither entity has social media or structured address fields. This forces users to lose information or resort to workarounds like stuffing multiple values into the notes body.

## What Changes

- **BREAKING**: Replace `email` (string) with `emails` (array of objects) on the people schema
- **BREAKING**: Replace `phone` (string) with `phones` (array of objects) on the people schema
- **BREAKING**: Replace `location` (string) with `addresses` (array of objects) on the companies schema
- Add `phones` (array of objects) to the companies schema
- Add `emails` (array of objects) to the companies schema
- Add `addresses` (array of objects) to the people schema
- Add `socials` (array of objects) to both people and companies schemas
- Each contact field entry is a labeled object with `type` (e.g., "work", "personal", "mobile") and `value`
- Update `SchemaMapper` to handle array-of-object properties so generated tools accept structured contact data
- Update `ToolGenerator` so generated create/update actions can accept and pass through structured array fields
- Migrate existing single-value `email`, `phone`, and `location` data on any existing entities to the new array format

## Capabilities

### New Capabilities

- `contact-fields`: Schema definition, validation, mapping, and tool generation for multi-value contact fields (phones, emails, addresses, socials) as arrays of typed objects on brain entities

### Modified Capabilities

_(none — no existing specs to modify)_

## Impact

- **Schemas**: `priv/workspace/brain/schemas/people.json` and `companies.json` — field renames and new array-of-object properties
- **SchemaMapper**: `lib/goodwizard/brain/schema_mapper.ex` — add mapping for `array` with `items.type = "object"` to a Jido-compatible type
- **ToolGenerator**: `lib/goodwizard/brain/tool_generator.ex` — ensure generated actions handle structured array params
- **Entity serialization**: `lib/goodwizard/brain/entity.ex` — verify YAML frontmatter round-trips arrays of objects correctly
- **Existing data**: Any existing people/company entities with `email`, `phone`, or `location` fields need migration to the new format
- **Tests**: Brain schema, entity, and tool generator tests will need updates for the new field shapes
