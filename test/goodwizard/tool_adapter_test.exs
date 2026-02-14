defmodule Goodwizard.ToolAdapterTest do
  use ExUnit.Case, async: true

  alias Jido.AI.ToolAdapter

  @filesystem_actions [
    Goodwizard.Actions.Filesystem.ReadFile,
    Goodwizard.Actions.Filesystem.WriteFile,
    Goodwizard.Actions.Filesystem.EditFile,
    Goodwizard.Actions.Filesystem.ListDir
  ]

  @all_actions @filesystem_actions ++ [Goodwizard.Actions.Shell.Exec]

  describe "from_actions/1 with filesystem actions" do
    test "converts 4 filesystem actions to tool definitions" do
      tools = ToolAdapter.from_actions(@filesystem_actions)

      assert length(tools) == 4
    end

    test "each tool has name, description, and parameter_schema" do
      tools = ToolAdapter.from_actions(@filesystem_actions)

      for tool <- tools do
        assert is_binary(tool.name)
        assert tool.name != ""
        assert is_binary(tool.description)
        assert tool.description != ""
        assert is_map(tool.parameter_schema)
      end
    end

    test "tool names match action names" do
      tools = ToolAdapter.from_actions(@filesystem_actions)
      names = Enum.map(tools, & &1.name) |> Enum.sort()

      assert names == ["edit_file", "list_dir", "read_file", "write_file"]
    end
  end

  describe "from_actions/1 with shell action" do
    test "converts Shell.Exec to tool definition" do
      tools = ToolAdapter.from_actions([Goodwizard.Actions.Shell.Exec])

      assert length(tools) == 1
      [tool] = tools
      assert tool.name == "exec"
      assert is_binary(tool.description)
    end

    test "Shell.Exec parameter schema includes command" do
      [tool] = ToolAdapter.from_actions([Goodwizard.Actions.Shell.Exec])

      properties = tool.parameter_schema["properties"]
      assert Map.has_key?(properties, "command")
    end
  end

  describe "from_actions/1 with all actions" do
    test "converts all 5 actions without name collisions" do
      tools = ToolAdapter.from_actions(@all_actions)

      assert length(tools) == 5
      names = Enum.map(tools, & &1.name)
      assert length(Enum.uniq(names)) == 5
    end
  end

  describe "parameter schema types" do
    test "string fields map to string type in JSON schema" do
      [tool] = ToolAdapter.from_actions([Goodwizard.Actions.Filesystem.ReadFile])

      properties = tool.parameter_schema["properties"]
      assert properties["path"]["type"] == "string"
    end
  end
end
