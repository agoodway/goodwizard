defmodule Goodwizard.Actions.Memory.ErrorPathsTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.AppendHistory
  alias Goodwizard.Actions.Memory.ReadLongTerm
  alias Goodwizard.Actions.Memory.SearchHistory
  alias Goodwizard.Actions.Memory.WriteLongTerm

  describe "path traversal rejection" do
    test "AppendHistory rejects path traversal" do
      assert {:error, msg} =
               AppendHistory.run(%{memory_dir: "/tmp/../../../etc", entry: "test"}, %{})

      assert msg =~ "path traversal"
    end

    test "ReadLongTerm rejects path traversal" do
      assert {:error, msg} = ReadLongTerm.run(%{memory_dir: "/tmp/../../etc"}, %{})
      assert msg =~ "path traversal"
    end

    test "SearchHistory rejects path traversal" do
      assert {:error, msg} =
               SearchHistory.run(%{memory_dir: "/tmp/../../../etc", pattern: "x"}, %{})

      assert msg =~ "path traversal"
    end

    test "WriteLongTerm rejects path traversal" do
      assert {:error, msg} =
               WriteLongTerm.run(
                 %{memory_dir: "/tmp/../../../etc", content: "evil"},
                 %{}
               )

      assert msg =~ "path traversal"
    end
  end

  describe "WriteLongTerm content size limit" do
    test "rejects content exceeding 100KB" do
      dir = Path.join(System.tmp_dir!(), "test_memory_size_#{:rand.uniform(100_000)}")
      on_exit(fn -> File.rm_rf!(dir) end)

      large_content = String.duplicate("x", 100 * 1024 + 1)

      assert {:error, msg} =
               WriteLongTerm.run(%{memory_dir: dir, content: large_content}, %{})

      assert msg =~ "exceeds maximum size"
    end

    test "accepts content at exactly 100KB" do
      dir = Path.join(System.tmp_dir!(), "test_memory_size_#{:rand.uniform(100_000)}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      content = String.duplicate("x", 100 * 1024)

      assert {:ok, _} = WriteLongTerm.run(%{memory_dir: dir, content: content}, %{})
    end
  end

  describe "file permission errors" do
    test "AppendHistory returns error for read-only directory" do
      dir = Path.join(System.tmp_dir!(), "test_memory_ro_#{:rand.uniform(100_000)}")
      File.mkdir_p!(dir)
      File.chmod!(dir, 0o444)

      on_exit(fn ->
        File.chmod!(dir, 0o755)
        File.rm_rf!(dir)
      end)

      assert {:error, msg} =
               AppendHistory.run(%{memory_dir: dir, entry: "test"}, %{})

      assert msg =~ "Failed to append"
    end

    test "WriteLongTerm returns error for read-only directory" do
      dir = Path.join(System.tmp_dir!(), "test_memory_ro_#{:rand.uniform(100_000)}")
      File.mkdir_p!(dir)
      File.chmod!(dir, 0o444)

      on_exit(fn ->
        File.chmod!(dir, 0o755)
        File.rm_rf!(dir)
      end)

      assert {:error, msg} =
               WriteLongTerm.run(%{memory_dir: dir, content: "test"}, %{})

      assert msg =~ "Failed to write"
    end

    test "SearchHistory returns empty matches when file unreadable" do
      dir = Path.join(System.tmp_dir!(), "test_memory_ro_#{:rand.uniform(100_000)}")
      File.mkdir_p!(dir)
      path = Path.join(dir, "HISTORY.md")
      File.write!(path, "some content\n")
      File.chmod!(path, 0o000)

      on_exit(fn ->
        File.chmod!(path, 0o644)
        File.rm_rf!(dir)
      end)

      assert {:ok, %{matches: []}} =
               SearchHistory.run(%{memory_dir: dir, pattern: "content"}, %{})
    end

    test "ReadLongTerm returns empty string when file unreadable" do
      dir = Path.join(System.tmp_dir!(), "test_memory_ro_#{:rand.uniform(100_000)}")
      File.mkdir_p!(dir)
      path = Path.join(dir, "MEMORY.md")
      File.write!(path, "some content")
      File.chmod!(path, 0o000)

      on_exit(fn ->
        File.chmod!(path, 0o644)
        File.rm_rf!(dir)
      end)

      assert {:ok, %{content: ""}} = ReadLongTerm.run(%{memory_dir: dir}, %{})
    end
  end

  describe "mkdir_p failures" do
    test "AppendHistory returns error when parent dir is read-only" do
      base = Path.join(System.tmp_dir!(), "test_memory_mkdirp_#{:rand.uniform(100_000)}")
      File.mkdir_p!(base)
      File.chmod!(base, 0o444)
      dir = Path.join(base, "subdir")

      on_exit(fn ->
        File.chmod!(base, 0o755)
        File.rm_rf!(base)
      end)

      assert {:error, msg} =
               AppendHistory.run(%{memory_dir: dir, entry: "test"}, %{})

      assert msg =~ "Failed to create memory directory"
    end

    test "WriteLongTerm returns error when parent dir is read-only" do
      base = Path.join(System.tmp_dir!(), "test_memory_mkdirp_#{:rand.uniform(100_000)}")
      File.mkdir_p!(base)
      File.chmod!(base, 0o444)
      dir = Path.join(base, "subdir")

      on_exit(fn ->
        File.chmod!(base, 0o755)
        File.rm_rf!(base)
      end)

      assert {:error, msg} =
               WriteLongTerm.run(%{memory_dir: dir, content: "test"}, %{})

      assert msg =~ "Failed to create memory directory"
    end
  end
end
