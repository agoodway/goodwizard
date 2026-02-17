defmodule Goodwizard.Memory.Entry do
  @moduledoc """
  Parsing and serialization for memory entry files (episodic and procedural).

  Memory entries use markdown with YAML frontmatter, similar to brain entities
  but without JSON Schema validation. Security constraints (anchor rejection,
  size limits) are enforced at parse time.

  Delegates to `Goodwizard.Frontmatter` for shared parse/serialize logic.
  """

  # 64 KB max frontmatter size to prevent memory exhaustion from large YAML
  @max_frontmatter_bytes 65_536

  # 1 MB max body size to prevent latency spikes during bulk operations
  @max_body_bytes 1_048_576

  # Combined max: frontmatter + body + overhead for fences and newlines
  @max_content_bytes @max_frontmatter_bytes + @max_body_bytes + 1_024

  @doc """
  Parses a markdown string with YAML frontmatter into `{frontmatter_map, body_string}`.

  Returns `{:ok, {map, string}}` or `{:error, reason}`.

  ## Error reasons

  - `:content_too_large` — total input exceeds combined limit before splitting
  - `:missing_frontmatter` — no `---` fences found
  - `:yaml_anchors_not_allowed` — YAML anchor (`&`) or alias (`*`) syntax detected
  - `:frontmatter_too_large` — frontmatter exceeds 64 KB
  - `:body_too_large` — body exceeds 1 MB
  - `{:yaml_parse_error, reason}` — YAML parsing failed
  """
  @spec parse(String.t()) :: {:ok, {map(), String.t()}} | {:error, term()}
  def parse(content) when is_binary(content) do
    Goodwizard.Frontmatter.parse(content,
      max_content_bytes: @max_content_bytes,
      max_frontmatter_bytes: @max_frontmatter_bytes,
      max_body_bytes: @max_body_bytes
    )
  end

  @doc """
  Serializes a frontmatter map and body string into a markdown string with YAML frontmatter.

  The output is parseable by `parse/1` (roundtrip fidelity).
  """
  @spec serialize(map(), String.t()) :: String.t()
  defdelegate serialize(data, body \\ ""), to: Goodwizard.Frontmatter
end
