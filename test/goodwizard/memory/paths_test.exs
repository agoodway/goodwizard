defmodule Goodwizard.Memory.PathsTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Memory.Paths

  describe "history_path/1" do
    test "returns path to HISTORY.md" do
      assert Paths.history_path("/tmp/memory") == "/tmp/memory/HISTORY.md"
    end
  end

  describe "memory_path/1" do
    test "returns path to MEMORY.md" do
      assert Paths.memory_path("/tmp/memory") == "/tmp/memory/MEMORY.md"
    end
  end

  describe "validate_memory_dir/1" do
    test "accepts normal directory paths" do
      assert {:ok, _} = Paths.validate_memory_dir("/tmp/memory")
    end

    test "rejects paths with .." do
      assert {:error, "memory_dir contains path traversal"} =
               Paths.validate_memory_dir("/tmp/memory/../../etc")
    end

    test "rejects paths with null bytes" do
      assert {:error, "memory_dir contains null bytes"} =
               Paths.validate_memory_dir("/tmp/memory\0/evil")
    end

    test "rejects paths with non-printable characters" do
      assert {:error, "memory_dir contains non-printable characters"} =
               Paths.validate_memory_dir("/tmp/memory\x01/dir")
    end

    test "expands the path on success" do
      {:ok, expanded} = Paths.validate_memory_dir("/tmp/./memory")
      assert expanded == "/tmp/memory"
    end
  end

  describe "ensure_dir/1" do
    test "creates directory" do
      dir = Path.join(System.tmp_dir!(), "test_paths_#{:rand.uniform(100_000)}")
      on_exit(fn -> File.rm_rf!(dir) end)

      refute File.exists?(dir)
      assert :ok = Paths.ensure_dir(dir)
      assert File.dir?(dir)
    end
  end

  describe "episodic_dir/1" do
    test "returns path with /episodic appended" do
      assert Paths.episodic_dir("/tmp/memory") == "/tmp/memory/episodic"
    end
  end

  describe "procedural_dir/1" do
    test "returns path with /procedural appended" do
      assert Paths.procedural_dir("/tmp/memory") == "/tmp/memory/procedural"
    end
  end

  describe "episode_path/2" do
    test "returns path to specific episode file" do
      assert Paths.episode_path("/tmp/memory", "abc123") == "/tmp/memory/episodic/abc123.md"
    end
  end

  describe "procedure_path/2" do
    test "returns path to specific procedure file" do
      assert Paths.procedure_path("/tmp/memory", "def456") == "/tmp/memory/procedural/def456.md"
    end
  end

  describe "validate_memory_subdir/2" do
    test "accepts episodic subdirectory" do
      assert {:ok, "/tmp/memory/episodic"} =
               Paths.validate_memory_subdir("/tmp/memory", "episodic")
    end

    test "accepts procedural subdirectory" do
      assert {:ok, "/tmp/memory/procedural"} =
               Paths.validate_memory_subdir("/tmp/memory", "procedural")
    end

    test "rejects unknown subdirectory name" do
      assert {:error, :invalid_subdir} = Paths.validate_memory_subdir("/tmp/memory", "custom")
    end

    test "rejects path traversal in subdirectory name" do
      assert {:error, :invalid_subdir} =
               Paths.validate_memory_subdir("/tmp/memory", "../secrets")
    end

    test "rejects empty subdirectory name" do
      assert {:error, :invalid_subdir} = Paths.validate_memory_subdir("/tmp/memory", "")
    end
  end
end
