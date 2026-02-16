defmodule Goodwizard.Brain.IdTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Brain.Id

  @uuid_regex ~r/^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/

  describe "generate/0" do
    test "returns a valid UUIDv7 string" do
      assert {:ok, id} = Id.generate()
      assert Regex.match?(@uuid_regex, id)
    end

    test "generated ID has version nibble 7" do
      {:ok, id} = Id.generate()
      # Version nibble is the 13th hex character (first of the 3rd group)
      assert String.at(id, 14) == "7"
    end

    test "generated ID has variant bits in [89ab]" do
      {:ok, id} = Id.generate()
      # Variant nibble is at position 19 (first char of 4th group)
      assert String.at(id, 19) in ~w(8 9 a b)
    end

    test "generates unique IDs on successive calls" do
      {:ok, id1} = Id.generate()
      {:ok, id2} = Id.generate()
      {:ok, id3} = Id.generate()

      assert id1 != id2
      assert id2 != id3
      assert id1 != id3
    end

    test "generated IDs are time-ordered" do
      {:ok, id1} = Id.generate()
      Process.sleep(2)
      {:ok, id2} = Id.generate()

      assert id1 < id2
    end

    test "generates unique IDs under concurrent access" do
      ids =
        1..50
        |> Task.async_stream(fn _ -> Id.generate() end, max_concurrency: 10)
        |> Enum.map(fn {:ok, {:ok, id}} -> id end)

      assert length(ids) == 50
      assert length(Enum.uniq(ids)) == 50
    end
  end

  describe "generate/1 (deprecated)" do
    test "delegates to generate/0" do
      assert {:ok, id} = Id.generate("/tmp/unused")
      assert Regex.match?(@uuid_regex, id)
    end
  end

  describe "valid?/1" do
    test "accepts a valid UUID" do
      assert Id.valid?("0193a5e7-8b4c-7f2a-9d1e-3b5c6d7e8f9a")
    end

    test "accepts a generated UUID" do
      {:ok, id} = Id.generate()
      assert Id.valid?(id)
    end

    test "rejects sqids-format strings" do
      refute Id.valid?("abcd1234")
    end

    test "rejects uppercase UUID" do
      refute Id.valid?("0193A5E7-8B4C-7F2A-9D1E-3B5C6D7E8F9A")
    end

    test "rejects empty string" do
      refute Id.valid?("")
    end

    test "rejects UUID without hyphens" do
      refute Id.valid?("0193a5e78b4c7f2a9d1e3b5c6d7e8f9a")
    end

    test "rejects non-binary input" do
      refute Id.valid?(12_345_678)
    end

    test "rejects UUID with wrong hyphen positions" do
      refute Id.valid?("0193a5e78-b4c-7f2a-9d1e-3b5c6d7e8f9a")
    end

    test "rejects UUID with extra hyphens" do
      refute Id.valid?("0193a5e7-8b4c-7f2a-9d1e-3b5c-6d7e8f9a")
    end

    test "rejects UUID with special characters" do
      refute Id.valid?("0193a5e7-8b4c-7f2a-9d1e-3b5c6d7e8f!a")
    end

    test "rejects UUIDv4 (version nibble 4)" do
      refute Id.valid?("550e8400-e29b-41d4-a716-446655440000")
    end

    test "rejects UUID with invalid variant bits" do
      # variant nibble 0 is not in [89ab]
      refute Id.valid?("0193a5e7-8b4c-7f2a-0d1e-3b5c6d7e8f9a")
    end
  end

  describe "id_pattern/0" do
    test "returns the UUIDv7 regex pattern string" do
      assert Id.id_pattern() ==
               "^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
    end
  end
end
