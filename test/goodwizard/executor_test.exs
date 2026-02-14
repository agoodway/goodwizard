defmodule Goodwizard.ExecutorTest do
  use ExUnit.Case, async: true

  alias Jido.AI.Executor

  @all_actions [
    Goodwizard.Actions.Filesystem.ReadFile,
    Goodwizard.Actions.Filesystem.WriteFile,
    Goodwizard.Actions.Filesystem.EditFile,
    Goodwizard.Actions.Filesystem.ListDir,
    Goodwizard.Actions.Shell.Exec
  ]

  setup do
    workspace = Path.join(System.tmp_dir!(), "executor_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(workspace)
    on_cleanup(fn -> File.rm_rf!(workspace) end)
    %{workspace: workspace}
  end

  defp on_cleanup(fun), do: ExUnit.Callbacks.on_exit(fun)

  describe "build_tools_map/1" do
    test "builds map from all action modules" do
      tools_map = Executor.build_tools_map(@all_actions)

      assert map_size(tools_map) == 5
      assert Map.has_key?(tools_map, "read_file")
      assert Map.has_key?(tools_map, "write_file")
      assert Map.has_key?(tools_map, "edit_file")
      assert Map.has_key?(tools_map, "list_dir")
      assert Map.has_key?(tools_map, "exec")
    end
  end

  describe "execute/4 with string-to-atom normalization" do
    test "executes read_file with string keys", %{workspace: workspace} do
      test_file = Path.join(workspace, "test.txt")
      File.write!(test_file, "hello world")

      tools_map = Executor.build_tools_map(@all_actions)

      {:ok, result} =
        Executor.execute(
          "read_file",
          %{"path" => test_file},
          %{},
          tools: tools_map
        )

      assert result.content == "hello world"
    end

    test "executes list_dir with string keys", %{workspace: workspace} do
      File.write!(Path.join(workspace, "a.txt"), "")
      File.mkdir_p!(Path.join(workspace, "subdir"))

      tools_map = Executor.build_tools_map(@all_actions)

      {:ok, result} =
        Executor.execute(
          "list_dir",
          %{"path" => workspace},
          %{},
          tools: tools_map
        )

      assert result.entries =~ "a.txt"
      assert result.entries =~ "subdir"
    end

    test "returns error for unknown tool" do
      tools_map = Executor.build_tools_map(@all_actions)

      {:error, error} =
        Executor.execute(
          "unknown_tool",
          %{},
          %{},
          tools: tools_map
        )

      assert error.type == :not_found
      assert error.error =~ "unknown_tool"
    end

    test "returns action error without crashing", %{workspace: workspace} do
      tools_map = Executor.build_tools_map(@all_actions)

      {:error, _error} =
        Executor.execute(
          "read_file",
          %{"path" => Path.join(workspace, "nonexistent.txt")},
          %{},
          tools: tools_map
        )
    end
  end
end
