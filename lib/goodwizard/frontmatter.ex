defmodule Goodwizard.Frontmatter do
  @moduledoc """
  Shared parsing and serialization for markdown files with YAML frontmatter.

  Used by both `Goodwizard.Brain.Entity` and `Goodwizard.Memory.Entry` to
  avoid duplicating frontmatter handling logic.
  """

  @doc """
  Parses a markdown string with YAML frontmatter into `{frontmatter_map, body_string}`.

  Accepts an optional keyword list of options:

    * `:max_content_bytes` — reject input exceeding this total size (default: no limit)
    * `:max_frontmatter_bytes` — reject frontmatter exceeding this size (default: 65_536)
    * `:max_body_bytes` — reject body exceeding this size (default: no limit)

  Returns `{:ok, {map, string}}` or `{:error, reason}`.

  ## Error reasons

    * `:content_too_large` — total input exceeds `:max_content_bytes`
    * `:missing_frontmatter` — no `---` fences found
    * `:yaml_anchors_not_allowed` — YAML anchor (`&`) or alias (`*`) syntax detected
    * `:frontmatter_too_large` — frontmatter exceeds `:max_frontmatter_bytes`
    * `:body_too_large` — body exceeds `:max_body_bytes`
    * `:invalid_frontmatter` — YAML parsed to a non-map value
    * `{:yaml_parse_error, reason}` — YAML parsing failed
  """
  @spec parse(String.t(), keyword()) :: {:ok, {map(), String.t()}} | {:error, term()}
  def parse(content, opts \\ []) when is_binary(content) do
    max_content = Keyword.get(opts, :max_content_bytes)
    max_fm = Keyword.get(opts, :max_frontmatter_bytes, 65_536)
    max_body = Keyword.get(opts, :max_body_bytes)

    if max_content && byte_size(content) > max_content do
      {:error, :content_too_large}
    else
      split_and_parse(content, max_fm, max_body)
    end
  end

  defp split_and_parse(content, max_fm, max_body) do
    case String.split(content, ~r/^---\r?$/m, parts: 3) do
      ["", frontmatter, _body] when byte_size(frontmatter) > max_fm ->
        {:error, :frontmatter_too_large}

      ["", _frontmatter, body] when is_integer(max_body) and byte_size(body) > max_body ->
        {:error, :body_too_large}

      ["", frontmatter, body] ->
        if has_yaml_anchors?(frontmatter) do
          {:error, :yaml_anchors_not_allowed}
        else
          parse_frontmatter(frontmatter, body)
        end

      _ ->
        {:error, :missing_frontmatter}
    end
  end

  # Detects YAML anchor (&name) and alias (*name) syntax at value positions.
  # Checks after colon (map values), after dash (list items), and at line start.
  # Avoids false positives on URLs and natural text containing & or *.
  defp has_yaml_anchors?(frontmatter) do
    Regex.match?(~r/(?::\s*|-\s+|^\s*)[&*]/m, frontmatter)
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
    encoded_key = encode_yaml_key(to_string(key))
    "#{encoded_key}: #{encode_yaml_value(value)}"
  end

  # Keys must be safe YAML identifiers. Quote if they contain special characters.
  defp encode_yaml_key(key) do
    if needs_quoting?(key) do
      ~s("#{escape_yaml_string(key)}")
    else
      key
    end
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
        encoded_key = encode_yaml_key(to_string(k))
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
