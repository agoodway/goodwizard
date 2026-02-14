defmodule Goodwizard.Plugins.PromptSkills.Parser do
  @moduledoc """
  Parses Claude Code-compatible SKILL.md frontmatter.

  Extracts `name` (required), `description` (required), and any extra fields
  as passthrough `meta`. Strips frontmatter from the body content.
  """

  @name_pattern ~r/^[a-z0-9-]+$/
  @max_name_length 64
  @max_description_length 1024
  @yaml_parse_timeout_ms 5_000

  @doc """
  Parse YAML frontmatter from SKILL.md content.

  Returns `{:ok, %{name: String.t(), description: String.t(), meta: map()}, body}`
  or `{:error, reason}`.
  """
  @spec parse_frontmatter(String.t()) :: {:ok, map(), String.t()} | {:error, String.t()}
  def parse_frontmatter(content) when is_binary(content) do
    case split_frontmatter(content) do
      {:ok, yaml_str, body} ->
        case parse_yaml_with_timeout(yaml_str) do
          {:ok, parsed} when is_map(parsed) ->
            extract_fields(parsed, body)

          {:ok, _} ->
            {:error, "frontmatter must be a YAML mapping"}

          {:error, :timeout} ->
            {:error, "YAML parsing timed out"}

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

  defp parse_yaml_with_timeout(yaml_str) do
    task = Task.async(fn -> YamlElixir.read_from_string(yaml_str) end)

    case Task.yield(task, @yaml_parse_timeout_ms) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
    end
  end

  # Split content into frontmatter YAML and body.
  # Frontmatter is delimited by --- on its own line at the start of the file.
  defp split_frontmatter(content) do
    # Normalize CRLF to LF for consistent line splitting
    normalized = String.replace(content, "\r\n", "\n")

    case String.split(normalized, "\n", parts: 2) do
      [first_line, rest] ->
        if String.trim(first_line) == "---" do
          find_closing_delimiter(rest)
        else
          {:error, "no frontmatter found"}
        end

      [_single_line] ->
        {:error, "no frontmatter found"}

      [] ->
        {:error, "no frontmatter found"}
    end
  end

  defp find_closing_delimiter(rest) do
    lines = String.split(rest, "\n")

    case Enum.find_index(lines, &(String.trim(&1) == "---")) do
      nil ->
        {:error, "no frontmatter found"}

      idx ->
        yaml_str = lines |> Enum.take(idx) |> Enum.join("\n")
        body = lines |> Enum.drop(idx + 1) |> Enum.join("\n") |> String.trim_leading()
        {:ok, yaml_str, body}
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
