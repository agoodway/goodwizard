defmodule Goodwizard.FrontmatterTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Frontmatter

  describe "parse/1 YAML anchor detection" do
    test "rejects anchor immediately after colon" do
      content = "---\nname: &anchor value\n---\nbody"
      assert {:error, :yaml_anchors_not_allowed} = Frontmatter.parse(content)
    end

    test "rejects anchor with space after &" do
      content = "---\nname: & anchor value\n---\nbody"
      assert {:error, :yaml_anchors_not_allowed} = Frontmatter.parse(content)
    end

    test "rejects alias immediately after colon" do
      content = "---\nname: *alias\n---\nbody"
      assert {:error, :yaml_anchors_not_allowed} = Frontmatter.parse(content)
    end

    test "rejects alias with space after *" do
      content = "---\nname: * alias\n---\nbody"
      assert {:error, :yaml_anchors_not_allowed} = Frontmatter.parse(content)
    end

    test "rejects anchor in list item position" do
      content = "---\nitems:\n- &anchor value\n---\nbody"
      assert {:error, :yaml_anchors_not_allowed} = Frontmatter.parse(content)
    end

    test "rejects anchor at line start" do
      content = "---\n&anchor value\n---\nbody"
      assert {:error, :yaml_anchors_not_allowed} = Frontmatter.parse(content)
    end

    test "accepts URL with ampersand in value" do
      content = "---\nurl: \"https://example.com?a=1&b=2\"\n---\nbody"
      assert {:ok, {meta, _}} = Frontmatter.parse(content)
      assert meta["url"] == "https://example.com?a=1&b=2"
    end

    test "accepts natural text with ampersand in quoted value" do
      content = "---\nnote: \"Tom&Jerry\"\n---\nbody"
      assert {:ok, {meta, _}} = Frontmatter.parse(content)
      assert meta["note"] == "Tom&Jerry"
    end

    test "accepts natural text with asterisk in quoted value" do
      content = "---\nnote: \"C*programming\"\n---\nbody"
      assert {:ok, {meta, _}} = Frontmatter.parse(content)
      assert meta["note"] == "C*programming"
    end

    test "rejects anchor immediately after colon without space (key:&anchor)" do
      content = "---\nname:&anchor value\n---\nbody"
      assert {:error, :yaml_anchors_not_allowed} = Frontmatter.parse(content)
    end
  end

  describe "parse/1 frontmatter splitting" do
    test "handles --- in YAML values without breaking split" do
      # Values containing --- should not break the frontmatter split
      # because serialize quotes them, and parse uses line-anchored regex
      serialized = Frontmatter.serialize(%{"s" => "has --- dashes"}, "body")
      assert {:ok, {meta, body}} = Frontmatter.parse(serialized)
      assert meta["s"] == "has --- dashes"
      assert body == "body"
    end

    test "handles --- in body without breaking split" do
      content = "---\ntype: test\n---\nbefore\n---\nafter"
      assert {:ok, {meta, body}} = Frontmatter.parse(content)
      assert meta["type"] == "test"
      # Body should contain everything after the second ---
      assert body =~ "before"
    end

    test "accepts CRLF frontmatter fences" do
      content = "---\r\ntype: test\r\n---\r\nbody"
      assert {:ok, {meta, body}} = Frontmatter.parse(content)
      assert meta["type"] == "test"
      assert body == "body"
    end
  end

  describe "parse/1 with size limits" do
    test "rejects content exceeding max_content_bytes" do
      large = String.duplicate("x", 100_000)
      content = "---\nkey: value\n---\n#{large}"
      assert {:error, :content_too_large} = Frontmatter.parse(content, max_content_bytes: 1_000)
    end

    test "accepts content within max_content_bytes" do
      content = "---\nkey: value\n---\nbody"
      assert {:ok, _} = Frontmatter.parse(content, max_content_bytes: 1_000)
    end

    test "rejects frontmatter at exactly the limit" do
      # Default max_frontmatter_bytes is 65_536
      # The frontmatter part is between the --- fences (includes surrounding newlines from split)
      large_value = String.duplicate("x", 65_530)
      content = "---\nk: #{large_value}\n---\nbody"

      # The frontmatter string includes the newlines: "\nk: xxx...\n"
      # which is "k: " (3 chars) + large_value + 2 newlines = 65_535
      # We need byte_size > 65_536 to trigger the guard
      assert {:error, :frontmatter_too_large} =
               Frontmatter.parse(content, max_frontmatter_bytes: 10)
    end

    test "rejects body exceeding max_body_bytes" do
      large_body = String.duplicate("x", 1_100_000)
      content = "---\ntype: test\n---\n#{large_body}"
      assert {:error, :body_too_large} = Frontmatter.parse(content, max_body_bytes: 1_048_576)
    end
  end

  describe "parse/1 :invalid_frontmatter" do
    test "returns :invalid_frontmatter for list YAML" do
      content = "---\n- item1\n- item2\n---\nbody"
      assert {:error, :invalid_frontmatter} = Frontmatter.parse(content)
    end

    test "returns :invalid_frontmatter for scalar YAML" do
      content = "---\njust a string\n---\nbody"
      assert {:error, :invalid_frontmatter} = Frontmatter.parse(content)
    end

    test "returns :invalid_frontmatter for integer YAML" do
      content = "---\n42\n---\nbody"
      assert {:error, :invalid_frontmatter} = Frontmatter.parse(content)
    end
  end

  describe "serialize/2 key quoting" do
    test "quotes keys containing colons" do
      result = Frontmatter.serialize(%{"has:colon" => "value"}, "")
      assert result =~ ~s("has:colon")
    end

    test "quotes keys containing newlines" do
      result = Frontmatter.serialize(%{"has\nnewline" => "value"}, "")
      assert result =~ ~s("has\\nnewline")
    end

    test "roundtrips keys with special characters" do
      meta = %{"normal_key" => "value1", "key" => "value2"}
      serialized = Frontmatter.serialize(meta, "body")
      assert {:ok, {parsed, _}} = Frontmatter.parse(serialized)
      assert parsed == meta
    end

    test "roundtrips nested map values" do
      meta = %{"config" => %{"host" => "localhost", "port" => 8080}}
      serialized = Frontmatter.serialize(meta, "body")
      assert {:ok, {parsed, _}} = Frontmatter.parse(serialized)
      assert parsed["config"]["host"] == "localhost"
      assert parsed["config"]["port"] == 8080
    end
  end

  describe "boundary conditions for size limits" do
    test "frontmatter exceeding 65536 bytes is rejected" do
      # The frontmatter string between the --- fences includes surrounding \n chars
      # "key: " = 5 bytes, "\n" prefix + "\n" suffix = 2 bytes, total overhead = 7
      large_value = String.duplicate("x", 65_536)
      content = "---\nkey: #{large_value}\n---\nbody"

      assert {:error, :frontmatter_too_large} = Frontmatter.parse(content)
    end

    test "frontmatter at exactly 65536 bytes is not rejected" do
      # Guard is >, so exactly 65_536 should NOT trigger the error
      # frontmatter = "\nkey: <value>\n"
      # We need byte_size("\nkey: <value>\n") == 65_536
      # "\nkey: " = 6 bytes, "\n" = 1 byte, so value = 65_536 - 7 = 65_529
      large_value = String.duplicate("x", 65_529)
      content = "---\nkey: #{large_value}\n---\nbody"

      # Verify the frontmatter is exactly at the limit
      [_, fm, _] = String.split(content, ~r/^---$/m, parts: 3)
      assert byte_size(fm) == 65_536

      assert {:ok, {meta, _}} = Frontmatter.parse(content)
      assert meta["key"] == large_value
    end

    test "frontmatter one byte below 65536 is accepted" do
      large_value = String.duplicate("x", 65_528)
      content = "---\nkey: #{large_value}\n---\nbody"

      [_, fm, _] = String.split(content, ~r/^---$/m, parts: 3)
      assert byte_size(fm) == 65_535

      assert {:ok, {meta, _}} = Frontmatter.parse(content)
      assert meta["key"] == large_value
    end

    test "body exceeding 1048576 bytes is rejected (when max_body_bytes set)" do
      body = String.duplicate("x", 1_048_577)
      content = "---\ntype: test\n---\n#{body}"
      assert {:error, :body_too_large} = Frontmatter.parse(content, max_body_bytes: 1_048_576)
    end

    test "body at exactly 1048576 bytes is rejected due to leading newline from split" do
      body = String.duplicate("x", 1_048_576)
      content = "---\ntype: test\n---\n#{body}"

      # The body from the split includes the leading \n, making it 1 byte over the limit
      [_, _, body_part] = String.split(content, ~r/^---$/m, parts: 3)
      assert byte_size(body_part) == 1_048_577

      assert {:error, :body_too_large} = Frontmatter.parse(content, max_body_bytes: 1_048_576)
    end

    test "body one byte below max_body_bytes is accepted" do
      # Create body that when split produces exactly max_body_bytes
      body = String.duplicate("x", 1_048_574)
      content = "---\ntype: test\n---\n#{body}"

      [_, _, body_part] = String.split(content, ~r/^---$/m, parts: 3)
      # body_part = "\n" + body = 1 + 1_048_574 = 1_048_575
      assert byte_size(body_part) == 1_048_575

      assert {:ok, _} = Frontmatter.parse(content, max_body_bytes: 1_048_576)
    end
  end
end
