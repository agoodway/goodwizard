defmodule Goodwizard.Memory.Entry do
  @moduledoc """
  Parsing and serialization for memory entry files (episodic and procedural).

  Memory entries use markdown with YAML frontmatter, similar to brain entities
  but without JSON Schema validation. Security constraints (anchor rejection,
  size limits) are enforced at parse time.
  """

  # 64 KB max frontmatter size to prevent memory exhaustion from large YAML
  @max_frontmatter_bytes 65_536

  # 1 MB max body size to prevent latency spikes during bulk operations
  @max_body_bytes 1_048_576

  @doc """
  Parses a markdown string with YAML frontmatter into `{frontmatter_map, body_string}`.

  Returns `{:ok, {map, string}}` or `{:error, reason}`.

  ## Error reasons

  - `:missing_frontmatter` — no `---` fences found
  - `:yaml_anchors_not_allowed` — YAML anchor (`&`) or alias (`*`) syntax detected
  - `:frontmatter_too_large` — frontmatter exceeds 64 KB
  - `:body_too_large` — body exceeds 1 MB
  - `{:yaml_parse_error, reason}` — YAML parsing failed
  """
  @spec parse(String.t()) :: {:ok, {map(), String.t()}} | {:error, term()}
  def parse(content) when is_binary(content) do
    case String.split(content, "---", parts: 3) do
      ["", frontmatter, _body] when byte_size(frontmatter) > @max_frontmatter_bytes ->
        {:error, :frontmatter_too_large}

      ["", _frontmatter, body] when byte_size(body) > @max_body_bytes ->
        {:error, :body_too_large}

      ["", frontmatter, body] ->
        if Regex.match?(~r/[&*]\S/, frontmatter) do
          {:error, :yaml_anchors_not_allowed}
        else
          parse_frontmatter(frontmatter, body)
        end

      _ ->
        {:error, :missing_frontmatter}
    end
  end

  defp parse_frontmatter(frontmatter, body) do
    case YamlElixir.read_from_string(frontmatter) do
      {:ok, data} when is_map(data) ->
        {:ok, {stringify_keys(data), String.trim(body)}}

      {:ok, _} ->
        {:error, :invalid_frontmatter}

      {:error, reason} ->
        {:error, {:yaml_parse_error, reason}}
    end
  end

  @doc """
  Serializes a frontmatter map and body string into a markdown string with YAML frontmatter.

  The output is parseable by `parse/1` (roundtrip fidelity).
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
      |> Enum.map_join(", ", fn {k, v} ->
        encoded_key = encode_yaml_value(to_string(k))
        "#{encoded_key}: #{encode_yaml_value(v)}"
      end)

    "{#{inner}}"
  end

  defp needs_quoting?(value) do
    String.contains?(value, [
      ":",
      "#",
      "\"",
      "'",
      "\n",
      "\r",
      "\t",
      "\b",
      "\f",
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
    |> String.replace("\r", "\\r")
    |> String.replace("\t", "\\t")
    |> String.replace("\b", "\\b")
    |> String.replace("\f", "\\f")
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end
