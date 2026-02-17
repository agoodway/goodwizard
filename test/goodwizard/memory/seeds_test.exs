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

    test "returns :ok on success", %{tmp_dir: tmp_dir} do
      assert Seeds.seed(tmp_dir) == :ok
    end

    test "is idempotent — calling twice does not error", %{tmp_dir: tmp_dir} do
      assert Seeds.seed(tmp_dir) == :ok
      assert Seeds.seed(tmp_dir) == :ok

      assert File.dir?(Path.join(tmp_dir, "memory/episodic"))
      assert File.dir?(Path.join(tmp_dir, "memory/procedural"))
    end

    test "preserves existing MEMORY.md content", %{tmp_dir: tmp_dir} do
      memory_dir = Path.join(tmp_dir, "memory")
      File.mkdir_p!(memory_dir)
      memory_md = Path.join(memory_dir, "MEMORY.md")
      File.write!(memory_md, "User prefers dark mode")

      Seeds.seed(tmp_dir)

      assert File.read!(memory_md) == "User prefers dark mode"
    end
  end
end
