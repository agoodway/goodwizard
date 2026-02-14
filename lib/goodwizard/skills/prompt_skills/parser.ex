defmodule Goodwizard.Skills.PromptSkills.Parser do
  @moduledoc """
  Parses Claude Code-compatible SKILL.md frontmatter.

  Extracts `name` (required), `description` (required), and any extra fields
  as passthrough `meta`. Strips frontmatter from the body content.
  """

  @name_pattern ~r/^[a-z0-9-]+$/
  @max_name_length 64
  @max_description_length 1024

  @doc """
  Parse YAML frontmatter from SKILL.md content.

  Returns `{:ok, %{name: String.t(), description: String.t(), meta: map()}, body}`
  or `{:error, reason}`.
  """
  @spec parse_frontmatter(String.t()) :: {:ok, map(), String.t()} | {:error, String.t()}
  def parse_frontmatter(content) when is_binary(content) do
    case split_frontmatter(content) do
      {:ok, yaml_str, body} ->
        case YamlElixir.read_from_string(yaml_str) do
          {:ok, parsed} when is_map(parsed) ->
            extract_fields(parsed, body)

          {:ok, _} ->
            {:error, "frontmatter must be a YAML mapping"}

          {:error, _reason} ->
            {:error, "invalid YAML in frontmatter"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validate name and description constraints.

  Name must match `^[a-z0-9-]+$` and be at most 64 characters.
  Description must be at most 1024 characters.
  """
  @spec validate_metadata(map()) :: {:ok, map()} | {:error, String.t()}
  def validate_metadata(%{name: name, description: description} = metadata) do
    cond do
      String.length(name) > @max_name_length ->
        {:error, "name must be at most #{@max_name_length} characters"}

      not Regex.match?(@name_pattern, name) ->
        {:error, "name must match ^[a-z0-9-]+$"}

      String.length(description) > @max_description_length ->
        {:error, "description must be at most #{@max_description_length} characters"}

      true ->
        {:ok, metadata}
    end
  end

  # Split content into frontmatter YAML and body.
  # Frontmatter is delimited by --- at the start of the file.
  defp split_frontmatter(content) do
    case String.split(content, "\n", parts: 2) do
      [first_line | _] ->
        if String.trim(first_line) == "---" do
          rest = String.slice(content, String.length(first_line) + 1, String.length(content))
          find_closing_delimiter(rest)
        else
          {:error, "no frontmatter found"}
        end

      [] ->
        {:error, "no frontmatter found"}
    end
  end

  defp find_closing_delimiter(rest) do
    case :binary.match(rest, "\n---") do
      {pos, _len} ->
        yaml_str = binary_part(rest, 0, pos)
        # Skip past the \n---\n (or \n--- + EOF)
        after_delimiter = binary_part(rest, pos + 4, byte_size(rest) - pos - 4)

        # Strip optional newline right after closing ---
        body =
          case after_delimiter do
            "\n" <> rest_body -> rest_body
            other -> other
          end

        {:ok, yaml_str, String.trim_leading(body)}

      :nomatch ->
        {:error, "no frontmatter found"}
    end
  end

  defp extract_fields(parsed, body) do
    name = Map.get(parsed, "name")
    description = Map.get(parsed, "description")

    cond do
      is_nil(name) ->
        {:error, "missing required field: name"}

      is_nil(description) ->
        {:error, "missing required field: description"}

      true ->
        name_str = to_string(name)
        description_str = to_string(description)

        meta =
          parsed
          |> Map.drop(["name", "description"])

        {:ok, %{name: name_str, description: description_str, meta: meta}, body}
    end
  end
end
