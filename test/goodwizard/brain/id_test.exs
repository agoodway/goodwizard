defmodule Goodwizard.Brain.IdTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Brain.Id

  @uuid_regex ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

  describe "generate/1" do
    test "returns a valid UUIDv7 string" do
      assert {:ok, id} = Id.generate("/tmp/unused")
      assert Regex.match?(@uuid_regex, id)
    end

    test "generated ID has version nibble 7" do
      {:ok, id} = Id.generate("/tmp/unused")
      # Version nibble is the 13th hex character (first of the 3rd group)
      assert String.at(id, 14) == "7"
    end

    test "generates unique IDs on successive calls" do
      {:ok, id1} = Id.generate("/tmp/unused")
      {:ok, id2} = Id.generate("/tmp/unused")
      {:ok, id3} = Id.generate("/tmp/unused")

      assert id1 != id2
      assert id2 != id3
      assert id1 != id3
    end

    test "generated IDs are time-ordered" do
      {:ok, id1} = Id.generate("/tmp/unused")
      Process.sleep(2)
      {:ok, id2} = Id.generate("/tmp/unused")

      assert id1 < id2
    end

    test "generates unique IDs under concurrent access" do
      ids =
        1..50
        |> Task.async_stream(fn _ -> Id.generate("/tmp/unused") end, max_concurrency: 10)
        |> Enum.map(fn {:ok, {:ok, id}} -> id end)

      assert length(ids) == 50
      assert length(Enum.uniq(ids)) == 50
    end

    test "does not create any counter file" do
      workspace = Path.join(System.tmp_dir!(), "brain_id_test_#{:rand.uniform(100_000)}")
      File.mkdir_p!(Path.join([workspace, "brain"]))
      on_exit(fn -> File.rm_rf!(workspace) end)

      {:ok, _id} = Id.generate(workspace)

      refute File.exists?(Path.join([workspace, "brain", ".counter"]))
      refute File.exists?(Path.join([workspace, "brain", ".counter.lock"]))
    end
  end

  describe "valid?/1" do
    test "accepts a valid UUID" do
      assert Id.valid?("0193a5e7-8b4c-7f2a-9d1e-3b5c6d7e8f9a")
    end

    test "accepts a generated UUID" do
      {:ok, id} = Id.generate("/tmp/unused")
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
  end

  describe "id_pattern/0" do
    test "returns the UUID regex pattern string" do
      assert Id.id_pattern() ==
               "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
    end
  end
end
