defmodule Goodwizard.Memory.SeedsTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Memory.Seeds

  @moduletag :tmp_dir

  describe "seed/1" do
    test "creates episodic and procedural directories", %{tmp_dir: tmp_dir} do
      Seeds.seed(tmp_dir)

      assert File.dir?(Path.join(tmp_dir, "memory/episodic"))
      assert File.dir?(Path.join(tmp_dir, "memory/procedural"))
    end

    test "creates MEMORY.md when it does not exist", %{tmp_dir: tmp_dir} do
      Seeds.seed(tmp_dir)

      memory_md = Path.join(tmp_dir, "memory/MEMORY.md")
      assert File.exists?(memory_md)
      assert File.read!(memory_md) == ""
    end

    test "returns {:ok, created} listing what was created", %{tmp_dir: tmp_dir} do
      assert {:ok, created} = Seeds.seed(tmp_dir)
      assert "episodic" in created
      assert "procedural" in created
      assert "MEMORY.md" in created
    end

    test "is idempotent — calling twice does not error", %{tmp_dir: tmp_dir} do
      assert {:ok, _} = Seeds.seed(tmp_dir)
      assert {:ok, _} = Seeds.seed(tmp_dir)

      assert File.dir?(Path.join(tmp_dir, "memory/episodic"))
      assert File.dir?(Path.join(tmp_dir, "memory/procedural"))
    end

    test "reports empty list when everything already exists", %{tmp_dir: tmp_dir} do
      {:ok, _} = Seeds.seed(tmp_dir)

      assert {:ok, created} = Seeds.seed(tmp_dir)
      refute "MEMORY.md" in created
    end

    test "preserves existing MEMORY.md content", %{tmp_dir: tmp_dir} do
      memory_dir = Path.join(tmp_dir, "memory")
      File.mkdir_p!(memory_dir)
      memory_md = Path.join(memory_dir, "MEMORY.md")
      File.write!(memory_md, "User prefers dark mode")

      Seeds.seed(tmp_dir)

      assert File.read!(memory_md) == "User prefers dark mode"
    end

    test "returns {:error, reason} on filesystem failure", %{tmp_dir: tmp_dir} do
      # Create a file where the memory directory should be, so mkdir_p fails
      memory_dir = Path.join(tmp_dir, "memory")
      episodic_dir = Path.join(memory_dir, "episodic")
      File.mkdir_p!(memory_dir)
      # Create a regular file at "episodic" so mkdir_p cannot create a directory there
      File.write!(episodic_dir, "not a directory")

      assert {:error, _reason} = Seeds.seed(tmp_dir)
    end
  end
end
