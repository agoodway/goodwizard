defmodule Goodwizard.Channels.Telegram.FormatterTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Channels.Telegram.Formatter

  describe "to_telegram_html/1" do
    test "converts bold, italic, bold-italic, and strikethrough" do
      input = "***hot*** **bold** *italics* ~~old~~"

      assert Formatter.to_telegram_html(input) ==
               "<b><i>hot</i></b> <b>bold</b> <i>italics</i> <s>old</s>"
    end

    test "converts links and escapes URL entities" do
      input = "[API docs](https://example.com/api?v=2&format=json)"

      assert Formatter.to_telegram_html(input) ==
               ~s(<a href="https://example.com/api?v=2&amp;format=json">API docs</a>)
    end

    test "groups consecutive blockquote lines" do
      input = "> first\n> second\noutside"

      assert Formatter.to_telegram_html(input) ==
               "<blockquote>first\nsecond</blockquote>\noutside"
    end

    test "converts inline code and preserves markdown literals inside it" do
      input = "`a < b && **c**`"
      assert Formatter.to_telegram_html(input) == "<code>a &lt; b &amp;&amp; **c**</code>"
    end

    test "converts fenced code without language" do
      input = "```\n<div>**x**</div>\n```"

      assert Formatter.to_telegram_html(input) == "<pre>&lt;div&gt;**x**&lt;/div&gt;\n</pre>"
    end

    test "converts fenced code with language class" do
      input = "```elixir\nIO.puts(\"hi\")\n```"

      assert Formatter.to_telegram_html(input) ==
               "<pre><code class=\"language-elixir\">IO.puts(\"hi\")\n</code></pre>"
    end

    test "escapes HTML entities in plain text" do
      input = "x < 5 & y > 3"
      assert Formatter.to_telegram_html(input) == "x &lt; 5 &amp; y &gt; 3"
    end

    test "preserves plain text without markdown" do
      input = "Hello, how are you today?"
      assert Formatter.to_telegram_html(input) == input
    end

    test "returns empty string for empty input" do
      assert Formatter.to_telegram_html("") == ""
    end

    test "preserves unmatched markers as literal text" do
      input = "This has * but no closing and **still open"
      assert Formatter.to_telegram_html(input) == input
    end

    test "does not convert underscore-based italic and preserves snake_case" do
      input = "_hello_ config_file_path"
      assert Formatter.to_telegram_html(input) == input
    end

    test "does not convert markdown outside code placeholders only" do
      input = "`**not bold**` and **bold**"

      assert Formatter.to_telegram_html(input) == "<code>**not bold**</code> and <b>bold</b>"
    end
  end
end
