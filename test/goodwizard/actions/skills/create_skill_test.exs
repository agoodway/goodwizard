defmodule Goodwizard.Actions.Skills.CreateSkillTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Skills.CreateSkill

  defp tmp_workspace do
    dir =
      Path.join(System.tmp_dir!(), "create_skill_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    dir
  end

  defp context_with_workspace(workspace) do
    %{state: %{workspace: workspace}}
  end

  defp valid_params(overrides \\ %{}) do
    Map.merge(
      %{name: "my-tool", description: "Does cool things", content: "Use this tool when..."},
      overrides
    )
  end

  describe "run/2 — valid creation" do
    test "creates skill file in correct directory" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params()

      assert {:ok, %{path: path, name: "my-tool"}} = CreateSkill.run(params, context)
      assert path == Path.join([workspace, "skills", "my-tool", "SKILL.md"])
      assert File.exists?(path)
    end

    test "creates skills directory if it does not exist" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      skills_dir = Path.join(workspace, "skills")
      refute File.exists?(skills_dir)

      context = context_with_workspace(workspace)
      params = valid_params()

      assert {:ok, _} = CreateSkill.run(params, context)
      assert File.dir?(skills_dir)
    end

    test "returns success with file path and name" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params()

      assert {:ok, %{path: path, name: "my-tool"}} = CreateSkill.run(params, context)
      assert String.ends_with?(path, "skills/my-tool/SKILL.md")
    end
  end

  describe "run/2 — frontmatter generation" do
    test "generates frontmatter with name and description" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params()

      assert {:ok, %{path: path}} = CreateSkill.run(params, context)

      content = File.read!(path)
      assert content =~ "---\nname: my-tool\ndescription: Does cool things\n---\n"
      assert content =~ "Use this tool when..."
    end

    test "includes optional metadata in frontmatter" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{metadata: %{"author" => "goodwizard", "version" => "1.0"}})

      assert {:ok, %{path: path}} = CreateSkill.run(params, context)

      content = File.read!(path)
      assert content =~ "metadata:"
      assert content =~ "  author: \"goodwizard\""
      assert content =~ "  version: \"1.0\""
    end

    test "body content follows frontmatter" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{content: "# My Tool\n\nInstructions here."})

      assert {:ok, %{path: path}} = CreateSkill.run(params, context)

      content = File.read!(path)
      # body is everything after the second ---
      [_, body] = String.split(content, ~r/---\n/, parts: 3) |> tl()
      assert body == "# My Tool\n\nInstructions here."
    end
  end

  describe "run/2 — name validation" do
    test "accepts valid kebab-case name" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{name: "my-cool-tool"})

      assert {:ok, _} = CreateSkill.run(params, context)
    end

    test "accepts single-word name" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{name: "deploy"})

      assert {:ok, _} = CreateSkill.run(params, context)
    end

    test "rejects uppercase name" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{name: "MySkill"})

      assert {:error, "invalid skill name: MySkill" <> _} = CreateSkill.run(params, context)
    end

    test "rejects path traversal with .." do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{name: "../evil-skill"})

      assert {:error, "invalid skill name: ../evil-skill" <> _} = CreateSkill.run(params, context)
      refute File.exists?(Path.join([workspace, "..", "evil-skill", "SKILL.md"]))
    end

    test "rejects name with slashes" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{name: "skills/nested"})

      assert {:error, "invalid skill name: skills/nested" <> _} =
               CreateSkill.run(params, context)
    end

    test "rejects name with null bytes" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{name: "bad\0name"})

      assert {:error, "invalid skill name: " <> _} = CreateSkill.run(params, context)
    end

    test "rejects leading hyphen" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{name: "-leading"})

      assert {:error, "invalid skill name: -leading" <> _} = CreateSkill.run(params, context)
    end

    test "rejects trailing hyphen" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{name: "trailing-"})

      assert {:error, "invalid skill name: trailing-" <> _} = CreateSkill.run(params, context)
    end

    test "rejects name with spaces" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{name: "has space"})

      assert {:error, "invalid skill name: has space" <> _} = CreateSkill.run(params, context)
    end
  end

  describe "run/2 — overwrite protection" do
    test "rejects creating a skill that already exists" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{name: "existing-skill"})

      # Create the skill first
      assert {:ok, _} = CreateSkill.run(params, context)

      # Try to create it again
      assert {:error, "skill already exists: existing-skill"} = CreateSkill.run(params, context)
    end
  end

  describe "run/2 — workspace resolution" do
    test "returns error when workspace not in context" do
      context = %{state: %{}}
      params = valid_params()

      assert {:error, "workspace not found in context"} = CreateSkill.run(params, context)
    end
  end
end
