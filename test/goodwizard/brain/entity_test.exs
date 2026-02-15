defmodule Goodwizard.Brain.EntityTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Brain.Entity

  describe "parse/1" do
    test "parses frontmatter and body" do
      content = """
      ---
      id: abc12345
      name: John Doe
      ---

      Some notes here.
      """

      assert {:ok, {data, body}} = Entity.parse(content)
      assert data["id"] == "abc12345"
      assert data["name"] == "John Doe"
      assert body == "Some notes here."
    end

    test "parses empty body" do
      content = "---\nid: abc12345\n---\n"

      assert {:ok, {data, body}} = Entity.parse(content)
      assert data["id"] == "abc12345"
      assert body == ""
    end

    test "parses list values" do
      content = "---\ntags: [friend, colleague]\n---\n"

      assert {:ok, {data, _body}} = Entity.parse(content)
      assert data["tags"] == ["friend", "colleague"]
    end

    test "parses quoted strings" do
      content = ~s(---\ncompany: "companies/x9rku2dq"\n---\n)

      assert {:ok, {data, _body}} = Entity.parse(content)
      assert data["company"] == "companies/x9rku2dq"
    end

    test "returns error for missing frontmatter" do
      assert {:error, :missing_frontmatter} = Entity.parse("Just some text")
    end

    test "returns error for incomplete frontmatter" do
      assert {:error, :missing_frontmatter} = Entity.parse("---\nid: abc\n")
    end

    test "returns error for non-map YAML frontmatter" do
      content = "---\n- item1\n- item2\n---\n"
      assert {:error, :invalid_frontmatter} = Entity.parse(content)
    end

    test "returns error for scalar YAML frontmatter" do
      content = "---\njust a string\n---\n"
      assert {:error, :invalid_frontmatter} = Entity.parse(content)
    end

    test "returns error for oversized frontmatter" do
      large_value = String.duplicate("x", 70_000)
      content = "---\nkey: #{large_value}\n---\n"
      assert {:error, :frontmatter_too_large} = Entity.parse(content)
    end

    test "ensures keys are strings" do
      content = "---\ncount: 42\n---\n"

      assert {:ok, {data, _body}} = Entity.parse(content)
      assert data["count"] == 42
      assert Map.keys(data) |> Enum.all?(&is_binary/1)
    end
  end

  describe "serialize/2" do
    test "serializes data map and body" do
      data = %{"id" => "abc12345", "name" => "John Doe"}
      result = Entity.serialize(data, "Some notes.")

      assert String.starts_with?(result, "---\n")
      assert String.contains?(result, "id: abc12345")
      assert String.contains?(result, "name: John Doe")
      assert String.contains?(result, "---\n\nSome notes.")
    end

    test "serializes with empty body" do
      data = %{"id" => "abc12345"}
      result = Entity.serialize(data, "")

      assert result == "---\nid: abc12345\n---\n"
    end

    test "serializes default empty body" do
      data = %{"id" => "abc12345"}
      result = Entity.serialize(data)

      assert result == "---\nid: abc12345\n---\n"
    end

    test "sorts keys alphabetically" do
      data = %{"z_field" => "last", "a_field" => "first"}
      result = Entity.serialize(data)

      a_pos = :binary.match(result, "a_field") |> elem(0)
      z_pos = :binary.match(result, "z_field") |> elem(0)
      assert a_pos < z_pos
    end

    test "quotes strings containing special characters" do
      data = %{"note" => "has: colon"}
      result = Entity.serialize(data)

      assert String.contains?(result, ~s(note: "has: colon"))
    end

    test "serializes list values" do
      data = %{"tags" => ["friend", "colleague"]}
      result = Entity.serialize(data)

      assert String.contains?(result, "tags: [friend, colleague]")
    end

    test "serializes boolean and nil values" do
      data = %{"active" => true, "deleted" => false, "middle_name" => nil}
      result = Entity.serialize(data)

      assert String.contains?(result, "active: true")
      assert String.contains?(result, "deleted: false")
      assert String.contains?(result, "middle_name: null")
    end

    test "serializes integer and float values" do
      data = %{"count" => 42, "score" => 3.14}
      result = Entity.serialize(data)

      assert String.contains?(result, "count: 42")
      assert String.contains?(result, "score: 3.14")
    end

    test "serializes map values" do
      data = %{"coords" => %{"lat" => 40.7, "lng" => -74.0}}
      result = Entity.serialize(data)

      assert String.contains?(result, "coords: {lat: 40.7, lng: -74.0}")
    end

    test "roundtrips map values through serialize and parse" do
      data = %{"id" => "abc12345", "meta" => %{"source" => "import", "version" => 2}}
      serialized = Entity.serialize(data)
      assert {:ok, {parsed, _}} = Entity.parse(serialized)
      assert parsed["meta"]["source"] == "import"
      assert parsed["meta"]["version"] == 2
    end

    test "quotes strings containing each special character" do
      special_chars = [
        ":", "#", "\"", "'", "\n", "[", "]", "{", "}", ",",
        "&", "*", "?", "|", "-", "<", ">", "=", "!", "%", "@", "`"
      ]

      for char <- special_chars do
        value = "test#{char}value"
        data = %{"field" => value}
        result = Entity.serialize(data)

        assert String.contains?(result, "field: \""),
               "Expected quoting for char #{inspect(char)} but got: #{result}"
      end
    end

    test "quotes YAML boolean-like strings" do
      for word <- ["true", "false", "null", "yes", "no", "on", "off"] do
        data = %{"field" => word}
        result = Entity.serialize(data)

        assert String.contains?(result, "field: \"#{word}\""),
               "Expected quoting for #{word} but got: #{result}"
      end
    end

    test "quotes strings starting with digits" do
      data = %{"field" => "42things"}
      result = Entity.serialize(data)
      assert String.contains?(result, ~s(field: "42things"))
    end
  end

  describe "roundtrip" do
    test "serialize then parse returns original data and body" do
      data = %{"id" => "abc12345", "name" => "John Doe", "tags" => ["friend", "colleague"]}
      body = "Some notes about John."

      serialized = Entity.serialize(data, body)
      assert {:ok, {parsed_data, parsed_body}} = Entity.parse(serialized)

      assert parsed_data["id"] == data["id"]
      assert parsed_data["name"] == data["name"]
      assert parsed_data["tags"] == data["tags"]
      assert parsed_body == body
    end

    test "roundtrip with empty body" do
      data = %{"id" => "abc12345", "name" => "Test"}

      serialized = Entity.serialize(data)
      assert {:ok, {parsed_data, parsed_body}} = Entity.parse(serialized)

      assert parsed_data["id"] == data["id"]
      assert parsed_data["name"] == data["name"]
      assert parsed_body == ""
    end

    test "roundtrip with entity references" do
      data = %{"id" => "abc12345", "company" => "companies/x9rku2dq"}

      serialized = Entity.serialize(data)
      assert {:ok, {parsed_data, _body}} = Entity.parse(serialized)

      assert parsed_data["company"] == "companies/x9rku2dq"
    end
  end
end
