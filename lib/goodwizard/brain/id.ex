defmodule Goodwizard.Brain.Id do
  @moduledoc """
  UUIDv7-based entity ID generation.

  Generates time-ordered, universally unique IDs for brain entities
  using UUIDv7 via the `uniq` hex package.
  """

  @id_pattern_string "^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
  @id_pattern Regex.compile!(@id_pattern_string)

  @doc "Returns the ID pattern string for use in JSON Schema definitions."
  @spec id_pattern() :: String.t()
  def id_pattern, do: @id_pattern_string

  @doc """
  Generates a new unique UUIDv7 ID.

  Returns `{:ok, id}`.
  """
  @spec generate() :: {:ok, String.t()}
  def generate do
    {:ok, Uniq.UUID.uuid7()}
  end

  @doc """
  Generates a new unique UUIDv7 ID.

  The `workspace` parameter is accepted for API compatibility but not used —
  UUIDv7 generation is stateless and requires no filesystem access.
  Prefer `generate/0` for new code.
  """
  @deprecated "Use generate/0 instead"
  @spec generate(String.t()) :: {:ok, String.t()}
  def generate(_workspace) do
    generate()
  end

  @doc """
  Validates that a string matches the UUID pattern (lowercase hex, 8-4-4-4-12 with hyphens).
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(id) when is_binary(id), do: Regex.match?(@id_pattern, id)
  def valid?(_), do: false
end
