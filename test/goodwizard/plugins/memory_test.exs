defmodule Goodwizard.Plugins.MemoryTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Plugins.Memory

  defp tmp_memory_dir do
    dir = Path.join(System.tmp_dir!(), "test_memory_#{:rand.uniform(100_000)}")
    File.mkdir_p!(dir)
    dir
  end

  describe "mount/2" do
    test "initializes with memory_dir and empty content when MEMORY.md missing" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      {:ok, state} = Memory.mount(%{}, %{memory_dir: dir})
      assert state.memory_dir == dir
      assert state.long_term_content == ""
    end

    test "loads MEMORY.md content on mount" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(Path.join(dir, "MEMORY.md"), "User prefers dark mode")

      {:ok, state} = Memory.mount(%{}, %{memory_dir: dir})
      assert state.memory_dir == dir
      assert state.long_term_content == "User prefers dark mode"
    end

    test "expands home directory in memory_dir" do
      {:ok, state} = Memory.mount(%{}, %{memory_dir: "~/test_nonexistent"})
      assert state.memory_dir == Path.expand("~/test_nonexistent")
      assert state.long_term_content == ""
    end

    test "defaults to priv/workspace/memory when memory_dir is nil" do
      {:ok, state} = Memory.mount(%{}, %{memory_dir: nil})
      assert state.memory_dir == Path.expand("priv/workspace/memory")
    end

    test "defaults to priv/workspace/memory when memory_dir is empty" do
      {:ok, state} = Memory.mount(%{}, %{memory_dir: ""})
      assert state.memory_dir == Path.expand("priv/workspace/memory")
    end

    test "defaults to priv/workspace/memory when no config provided" do
      {:ok, state} = Memory.mount(%{}, %{})
      assert state.memory_dir == Path.expand("priv/workspace/memory")
    end
  end
end
