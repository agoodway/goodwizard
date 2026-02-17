defmodule Goodwizard.Memory.EntryTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Memory.Entry

  describe "parse/1" do
    test "parses well-formed entry with frontmatter and body" do
      content = """
      ---
      type: workflow
      summary: How to deploy
      ---
      Step 1: Build the release
      Step 2: Deploy to production
      """

      assert {:ok, {meta, body}} = Entry.parse(content)
      assert meta["type"] == "workflow"
      assert meta["summary"] == "How to deploy"
      assert body =~ "Step 1: Build the release"
      assert body =~ "Step 2: Deploy to production"
    end

    test "parses entry with empty body" do
      content = """
      ---
      type: episode
      ---
      """

      assert {:ok, {meta, ""}} = Entry.parse(content)
      assert meta["type"] == "episode"
    end

    test "returns string keys in frontmatter map" do
      content = """
      ---
      type: workflow
      priority: 1
      ---
      body
      """

      assert {:ok, {meta, _body}} = Entry.parse(content)
      assert Map.keys(meta) |> Enum.all?(&is_binary/1)
    end

    test "rejects content with no frontmatter" do
      assert {:error, :missing_frontmatter} = Entry.parse("just some text")
    end

    test "rejects content with only one fence" do
      assert {:error, :missing_frontmatter} = Entry.parse("---\ntype: test\n")
    end

    test "rejects YAML anchors" do
      content = """
      ---
      name: &anchor value
      ---
      body
      """

      assert {:error, :yaml_anchors_not_allowed} = Entry.parse(content)
    end

    test "rejects YAML aliases" do
      content = """
      ---
      name: *alias
      ---
      body
      """

      assert {:error, :yaml_anchors_not_allowed} = Entry.parse(content)
    end

    test "rejects oversized frontmatter" do
      large_value = String.duplicate("x", 66_000)

      content = "---\nkey: #{large_value}\n---\nbody"

      assert {:error, :frontmatter_too_large} = Entry.parse(content)
    end

    test "rejects oversized body" do
      large_body = String.duplicate("x", 1_100_000)

      content = "---\ntype: test\n---\n#{large_body}"

      assert {:error, :body_too_large} = Entry.parse(content)
    end

    test "handles integer values in frontmatter" do
      content = """
      ---
      priority: 5
      ---
      body
      """

      assert {:ok, {meta, _}} = Entry.parse(content)
      assert meta["priority"] == 5
    end

    test "handles boolean values in frontmatter" do
      content = """
      ---
      active: true
      archived: false
      ---
      body
      """

      assert {:ok, {meta, _}} = Entry.parse(content)
      assert meta["active"] == true
      assert meta["archived"] == false
    end

    test "handles list values in frontmatter" do
      content = """
      ---
      tags: [elixir, deploy]
      ---
      body
      """

      assert {:ok, {meta, _}} = Entry.parse(content)
      assert meta["tags"] == ["elixir", "deploy"]
    end

    test "handles null values in frontmatter" do
      content = """
      ---
      type: test
      notes: null
      ---
      body
      """

      assert {:ok, {meta, _}} = Entry.parse(content)
      assert meta["notes"] == nil
    end

    test "rejects YAML anchor with space after &" do
      content = "---\nname: & anchor value\n---\nbody"
      assert {:error, :yaml_anchors_not_allowed} = Entry.parse(content)
    end

    test "rejects YAML alias with space after *" do
      content = "---\nname: * alias\n---\nbody"
      assert {:error, :yaml_anchors_not_allowed} = Entry.parse(content)
    end

    test "accepts URL with ampersand in quoted value" do
      content = "---\nurl: \"https://example.com?a=1&b=2\"\n---\nbody"
      assert {:ok, {meta, _}} = Entry.parse(content)
      assert meta["url"] == "https://example.com?a=1&b=2"
    end

    test "rejects content exceeding combined size limit" do
      large = String.duplicate("x", 1_200_000)
      content = "---\ntype: test\n---\n#{large}"
      assert {:error, :content_too_large} = Entry.parse(content)
    end

    test "returns :invalid_frontmatter for non-map YAML" do
      content = "---\n- item1\n- item2\n---\nbody"
      assert {:error, :invalid_frontmatter} = Entry.parse(content)
    end
  end

  describe "serialize/2" do
    test "serializes map with string values" do
      result = Entry.serialize(%{"type" => "workflow", "summary" => "How to deploy"}, "Step 1...")
      assert result =~ "---\n"
      assert result =~ "type: workflow"
      assert result =~ "summary: How to deploy"
      assert result =~ "Step 1..."
    end

    test "serializes map with empty body" do
      result = Entry.serialize(%{"type" => "episode"})
      assert result =~ "---\n"
      assert result =~ "type: episode"
      refute result =~ "\n\n---"
    end

    test "serializes list values in inline format" do
      result = Entry.serialize(%{"tags" => ["elixir", "deploy"]}, "")
      assert result =~ "tags: [elixir, deploy]"
    end

    test "serializes integer values" do
      result = Entry.serialize(%{"priority" => 5}, "")
      assert result =~ "priority: 5"
    end

    test "serializes boolean values" do
      result = Entry.serialize(%{"active" => true, "archived" => false}, "")
      assert result =~ "active: true"
      assert result =~ "archived: false"
    end

    test "serializes nil values" do
      result = Entry.serialize(%{"notes" => nil}, "")
      assert result =~ "notes: null"
    end

    test "quotes values with special YAML characters" do
      result = Entry.serialize(%{"summary" => "step: one"}, "")
      assert result =~ ~s(summary: "step: one")
    end

    test "sorts keys alphabetically" do
      result = Entry.serialize(%{"z_key" => "last", "a_key" => "first"}, "body")
      lines = String.split(result, "\n")
      a_index = Enum.find_index(lines, &(&1 =~ "a_key"))
      z_index = Enum.find_index(lines, &(&1 =~ "z_key"))
      assert a_index < z_index
    end
  end

  describe "roundtrip fidelity" do
    test "parse(serialize(map, body)) returns original data" do
      meta = %{"type" => "workflow", "summary" => "How to deploy", "priority" => 1}
      body = "Step 1: Build the release"

      serialized = Entry.serialize(meta, body)
      assert {:ok, {parsed_meta, parsed_body}} = Entry.parse(serialized)
      assert parsed_meta == meta
      assert parsed_body == body
    end

    test "roundtrips with list values" do
      meta = %{"tags" => ["elixir", "deploy"], "type" => "procedure"}
      body = "Some instructions"

      serialized = Entry.serialize(meta, body)
      assert {:ok, {parsed_meta, parsed_body}} = Entry.parse(serialized)
      assert parsed_meta == meta
      assert parsed_body == body
    end

    test "roundtrips with boolean and nil values" do
      meta = %{"active" => true, "archived" => false, "notes" => nil}
      body = "Content here"

      serialized = Entry.serialize(meta, body)
      assert {:ok, {parsed_meta, parsed_body}} = Entry.parse(serialized)
      assert parsed_meta == meta
      assert parsed_body == body
    end

    test "roundtrips with empty body" do
      meta = %{"type" => "episode"}

      serialized = Entry.serialize(meta)
      assert {:ok, {parsed_meta, parsed_body}} = Entry.parse(serialized)
      assert parsed_meta == meta
      assert parsed_body == ""
    end

    test "roundtrips with special characters in values" do
      meta = %{"summary" => "deploy: step [1] with {braces}"}
      body = "Content"

      serialized = Entry.serialize(meta, body)
      assert {:ok, {parsed_meta, parsed_body}} = Entry.parse(serialized)
      assert parsed_meta == meta
      assert parsed_body == body
    end

    test "roundtrips with --- in values" do
      meta = %{"s" => "has --- dashes"}
      body = "body"

      serialized = Entry.serialize(meta, body)
      assert {:ok, {parsed_meta, parsed_body}} = Entry.parse(serialized)
      assert parsed_meta == meta
      assert parsed_body == body
    end

    test "roundtrips with keys containing special characters" do
      meta = %{"normal" => "value"}
      body = "body"

      serialized = Entry.serialize(meta, body)
      assert {:ok, {parsed_meta, parsed_body}} = Entry.parse(serialized)
      assert parsed_meta == meta
      assert parsed_body == body
    end
  end
end
