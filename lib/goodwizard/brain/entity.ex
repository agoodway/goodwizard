defmodule Goodwizard.Brain.Entity do
  @moduledoc """
  Parsing and serialization for brain entity files.

  Entity files use markdown with YAML frontmatter. Structured data lives
  in the frontmatter (validated by JSON Schema), while the body holds
  freeform notes.

  Delegates to `Goodwizard.Frontmatter` for shared parse/serialize logic.
  """

  # 64 KB max frontmatter size to prevent memory exhaustion from large YAML
  @max_frontmatter_bytes 65_536

  @doc """
  Parses a markdown string with YAML frontmatter into `{data_map, body_string}`.

  Returns `{:ok, {map, string}}` or `{:error, reason}`.
  """
  @spec parse(String.t()) :: {:ok, {map(), String.t()}} | {:error, term()}
  def parse(content) when is_binary(content) do
    Goodwizard.Frontmatter.parse(content, max_frontmatter_bytes: @max_frontmatter_bytes)
  end

  @doc """
  Serializes a data map and body string into a markdown string with YAML frontmatter.
  """
  @spec serialize(map(), String.t()) :: String.t()
  defdelegate serialize(data, body \\ ""), to: Goodwizard.Frontmatter
end
