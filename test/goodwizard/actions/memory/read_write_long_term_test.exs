defmodule Goodwizard.Actions.Memory.ReadWriteLongTermTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.ReadLongTerm
  alias Goodwizard.Actions.Memory.WriteLongTerm

  defp tmp_memory_dir do
    dir = Path.join(System.tmp_dir!(), "test_memory_rw_#{:rand.uniform(100_000)}")
    File.mkdir_p!(dir)
    dir
  end

  describe "ReadLongTerm" do
    test "returns empty string when MEMORY.md missing" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      assert {:ok, %{content: ""}} = ReadLongTerm.run(%{memory_dir: dir}, %{})
    end

    test "returns MEMORY.md content" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(Path.join(dir, "MEMORY.md"), "User likes Elixir")

      assert {:ok, %{content: "User likes Elixir"}} = ReadLongTerm.run(%{memory_dir: dir}, %{})
    end
  end

  describe "WriteLongTerm" do
    test "writes content to MEMORY.md" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      assert {:ok, %{message: message}} =
               WriteLongTerm.run(%{memory_dir: dir, content: "New memory content"}, %{})

      assert message =~ "Successfully wrote"
      assert File.read!(Path.join(dir, "MEMORY.md")) == "New memory content"
    end

    test "overwrites existing content" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(Path.join(dir, "MEMORY.md"), "Old content")

      WriteLongTerm.run(%{memory_dir: dir, content: "New content"}, %{})

      assert File.read!(Path.join(dir, "MEMORY.md")) == "New content"
    end

    test "creates file if missing" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      refute File.exists?(Path.join(dir, "MEMORY.md"))

      WriteLongTerm.run(%{memory_dir: dir, content: "Created!"}, %{})

      assert File.read!(Path.join(dir, "MEMORY.md")) == "Created!"
    end

    test "creates directory if missing" do
      base = Path.join(System.tmp_dir!(), "test_memory_rw_nested_#{:rand.uniform(100_000)}")
      dir = Path.join(base, "subdir")
      on_exit(fn -> File.rm_rf!(base) end)

      refute File.exists?(dir)

      WriteLongTerm.run(%{memory_dir: dir, content: "Nested!"}, %{})

      assert File.read!(Path.join(dir, "MEMORY.md")) == "Nested!"
    end
  end

  describe "read after write round-trip" do
    test "write then read returns same content" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      WriteLongTerm.run(%{memory_dir: dir, content: "Round trip test"}, %{})
      assert {:ok, %{content: "Round trip test"}} = ReadLongTerm.run(%{memory_dir: dir}, %{})
    end
  end
end
