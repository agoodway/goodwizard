defmodule Goodwizard.Brain.Entity do
  @moduledoc """
  Parsing and serialization for brain entity files.

  Entity files use markdown with YAML frontmatter. Structured data lives
  in the frontmatter (validated by JSON Schema), while the body holds
  freeform notes.
  """

  # 64 KB max frontmatter size to prevent memory exhaustion from large YAML
  @max_frontmatter_bytes 65_536

  @doc """
  Parses a markdown string with YAML frontmatter into `{data_map, body_string}`.

  Returns `{:ok, {map, string}}` or `{:error, reason}`.
  """
  @spec parse(String.t()) :: {:ok, {map(), String.t()}} | {:error, term()}
  def parse(content) when is_binary(content) do
    case String.split(content, "---", parts: 3) do
      ["", frontmatter, _body] when byte_size(frontmatter) > @max_frontmatter_bytes ->
        {:error, :frontmatter_too_large}

      ["", frontmatter, body] ->
        case YamlElixir.read_from_string(frontmatter) do
          {:ok, data} when is_map(data) ->
            {:ok, {stringify_keys(data), String.trim(body)}}

          {:ok, _} ->
            {:error, :invalid_frontmatter}

          {:error, reason} ->
            {:error, {:yaml_parse_error, reason}}
        end

      _ ->
        {:error, :missing_frontmatter}
    end
  end

  @doc """
  Serializes a data map and body string into a markdown string with YAML frontmatter.
  """
  @spec serialize(map(), String.t()) :: String.t()
  def serialize(data, body \\ "") when is_map(data) do
    yaml =
      data
      |> Enum.sort_by(fn {k, _} -> k end)
      |> Enum.map_join("\n", &encode_yaml_field/1)

    body_part = if body == "", do: "", else: "\n#{body}\n"

    "---\n#{yaml}\n---\n#{body_part}"
  end

  defp encode_yaml_field({key, value}) do
    "#{key}: #{encode_yaml_value(value)}"
  end

  defp encode_yaml_value(value) when is_binary(value) do
    if needs_quoting?(value) do
      ~s("#{escape_yaml_string(value)}")
    else
      value
    end
  end

  defp encode_yaml_value(value) when is_integer(value), do: Integer.to_string(value)
  defp encode_yaml_value(value) when is_float(value), do: Float.to_string(value)
  defp encode_yaml_value(true), do: "true"
  defp encode_yaml_value(false), do: "false"
  defp encode_yaml_value(nil), do: "null"

  defp encode_yaml_value(value) when is_list(value) do
    items = Enum.map_join(value, ", ", &encode_yaml_value/1)
    "[#{items}]"
  end

  defp encode_yaml_value(value) when is_map(value) do
    inner =
      value
      |> Enum.sort_by(fn {k, _} -> k end)
      |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{encode_yaml_value(v)}" end)

    "{#{inner}}"
  end

  defp needs_quoting?(value) do
    String.contains?(value, [
      ":",
      "#",
      "\"",
      "'",
      "\n",
      "[",
      "]",
      "{",
      "}",
      ",",
      "&",
      "*",
      "?",
      "|",
      "-",
      "<",
      ">",
      "=",
      "!",
      "%",
      "@",
      "`"
    ]) or
      value in ["true", "false", "null", "yes", "no", "on", "off", ""] or
      String.match?(value, ~r/^\d/)
  end

  defp escape_yaml_string(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end
