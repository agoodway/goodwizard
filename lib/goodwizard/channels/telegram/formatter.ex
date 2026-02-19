defmodule Goodwizard.Channels.Telegram.Formatter do
  @moduledoc """
  Converts markdown-like content into Telegram-compatible HTML.

  This module is intentionally introduced as a dedicated boundary so Telegram
  formatting can evolve independently from message generation.
  """

  @fenced_code_regex ~r/```([^\n`]*)\n(.*?)```/s
  @inline_code_regex ~r/`([^`\n]+?)`/
  @bold_italic_regex ~r/\*\*\*([^\n*]+)\*\*\*/
  @bold_regex ~r/\*\*([^\n*]+)\*\*/
  @italic_regex ~r/(?<!\*)\*([^*\n]+?)\*(?!\*)/
  @strikethrough_regex ~r/~~([^\n~]+)~~/
  @link_regex ~r/\[([^\]\n]+)\]\(([^)\n]+)\)/

  @doc """
  Converts text into Telegram-safe HTML.
  """
  @spec to_telegram_html(String.t()) :: String.t()
  def to_telegram_html(text) when is_binary(text) do
    placeholder_prefix = "__GW_TG_#{System.unique_integer([:positive])}"

    {text_without_fences, fenced_placeholders, next_index} =
      extract_placeholders(text, @fenced_code_regex, placeholder_prefix, 0, &render_fenced_code/1)

    {text_without_code, inline_placeholders, _next_index} =
      extract_placeholders(
        text_without_fences,
        @inline_code_regex,
        placeholder_prefix,
        next_index,
        &render_inline_code/1
      )

    text_without_code
    |> convert_markdown_and_escape()
    |> restore_placeholders(fenced_placeholders ++ inline_placeholders)
  end

  defp convert_markdown_and_escape(text) do
    text
    |> String.split("\n", trim: false)
    |> convert_lines([])
    |> Enum.join("\n")
  end

  defp convert_lines([], acc), do: Enum.reverse(acc)

  defp convert_lines([line | rest], acc) do
    if String.starts_with?(line, "> ") do
      {quote_lines, remaining} =
        Enum.split_while([line | rest], &String.starts_with?(&1, "> "))

      converted_quote =
        quote_lines
        |> Enum.map(&String.replace_prefix(&1, "> ", ""))
        |> Enum.map_join("\n", &convert_inline_markdown/1)

      convert_lines(remaining, ["<blockquote>#{converted_quote}</blockquote>" | acc])
    else
      convert_lines(rest, [convert_inline_markdown(line) | acc])
    end
  end

  defp convert_inline_markdown(text) do
    text
    |> escape_html()
    |> replace_regex(@bold_italic_regex, "<b><i>\\1</i></b>")
    |> replace_regex(@bold_regex, "<b>\\1</b>")
    |> replace_regex(@italic_regex, "<i>\\1</i>")
    |> replace_regex(@strikethrough_regex, "<s>\\1</s>")
    |> replace_links()
  end

  defp extract_placeholders(text, regex, prefix, start_index, renderer) do
    do_extract_placeholders(text, regex, prefix, start_index, renderer, [])
  end

  defp do_extract_placeholders(text, regex, prefix, index, renderer, acc) do
    case Regex.run(regex, text, return: :index) do
      nil ->
        {text, Enum.reverse(acc), index}

      [{start, length} | capture_indexes] ->
        captures =
          Enum.map(capture_indexes, fn
            {-1, 0} ->
              ""

            {capture_start, capture_length} ->
              binary_part(text, capture_start, capture_length)
          end)

        placeholder = "#{prefix}_#{index}__"
        rendered = renderer.(captures)

        prefix_text = binary_part(text, 0, start)
        suffix_start = start + length
        suffix_length = byte_size(text) - suffix_start
        suffix_text = binary_part(text, suffix_start, suffix_length)

        updated_text = prefix_text <> placeholder <> suffix_text

        do_extract_placeholders(
          updated_text,
          regex,
          prefix,
          index + 1,
          renderer,
          [{placeholder, rendered} | acc]
        )
    end
  end

  defp render_inline_code([code]) do
    "<code>#{escape_html(code)}</code>"
  end

  defp render_fenced_code([language, code]) do
    escaped_code = escape_html(code)
    normalized_language = normalize_language(language)

    if normalized_language == "" do
      "<pre>#{escaped_code}</pre>"
    else
      ~s(<pre><code class="language-#{normalized_language}">#{escaped_code}</code></pre>)
    end
  end

  defp normalize_language(language) do
    language
    |> String.trim()
    |> String.replace(~r/[^A-Za-z0-9_-]/, "")
  end

  defp restore_placeholders(text, placeholders) do
    Enum.reduce(placeholders, text, fn {placeholder, replacement}, acc ->
      String.replace(acc, placeholder, replacement)
    end)
  end

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp escape_attribute(value) do
    String.replace(value, "\"", "&quot;")
  end

  defp replace_regex(text, regex, replacement) do
    Regex.replace(regex, text, replacement)
  end

  defp replace_links(text) do
    Regex.replace(@link_regex, text, fn _, label, url ->
      ~s(<a href="#{escape_attribute(url)}">#{label}</a>)
    end)
  end
end
