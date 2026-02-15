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
      assert content =~ "---\nname: my-tool\ndescription: \"Does cool things\"\n---\n"
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
      assert content =~ ~s(  author: "goodwizard")
      assert content =~ ~s(  version: "1.0")
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

    test "omits metadata section when metadata is empty map" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{metadata: %{}})

      assert {:ok, %{path: path}} = CreateSkill.run(params, context)

      content = File.read!(path)
      refute content =~ "metadata:"
    end

    test "formats integer metadata values" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{metadata: %{"priority" => 5}})

      assert {:ok, %{path: path}} = CreateSkill.run(params, context)

      content = File.read!(path)
      assert content =~ "  priority: 5"
    end

    test "formats boolean metadata values" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{metadata: %{"active" => true}})

      assert {:ok, %{path: path}} = CreateSkill.run(params, context)

      content = File.read!(path)
      assert content =~ "  active: true"
    end

    test "formats atom metadata values" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{metadata: %{"status" => :draft}})

      assert {:ok, %{path: path}} = CreateSkill.run(params, context)

      content = File.read!(path)
      assert content =~ "  status: draft"
    end

    test "escapes description with colons" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{description: "Key: value pair handler"})

      assert {:ok, %{path: path}} = CreateSkill.run(params, context)

      content = File.read!(path)
      assert content =~ ~s(description: "Key: value pair handler")
    end

    test "escapes description with hash characters" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{description: "Handle # comments"})

      assert {:ok, %{path: path}} = CreateSkill.run(params, context)

      content = File.read!(path)
      assert content =~ ~s(description: "Handle # comments")
    end

    test "accepts empty description" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{description: ""})

      assert {:ok, %{path: path}} = CreateSkill.run(params, context)

      content = File.read!(path)
      assert content =~ ~s(description: "")
    end

    test "accepts empty content body" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{content: ""})

      assert {:ok, %{path: path}} = CreateSkill.run(params, context)

      content = File.read!(path)
      assert String.ends_with?(content, "---\n")
    end

    test "escapes description with quotes" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{description: ~s(Say "hello" world)})

      assert {:ok, %{path: path}} = CreateSkill.run(params, context)

      content = File.read!(path)
      assert content =~ ~s(description: "Say \\"hello\\" world")
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

    test "accepts single-character name" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{name: "x"})

      assert {:ok, _} = CreateSkill.run(params, context)
    end

    test "accepts exact 64-character name" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      name = String.duplicate("a", 64)
      params = valid_params(%{name: name})

      assert {:ok, _} = CreateSkill.run(params, context)
    end

    test "rejects 65-character name" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      name = String.duplicate("a", 65)
      params = valid_params(%{name: name})

      assert {:error, "invalid skill name: " <> _} = CreateSkill.run(params, context)
    end

    test "rejects empty string name" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{name: ""})

      assert {:error, "invalid skill name: " <> _} = CreateSkill.run(params, context)
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

      assert {:error, msg} = CreateSkill.run(params, context)
      assert msg =~ "dangerous characters"
      refute File.exists?(Path.join([workspace, "..", "evil-skill", "SKILL.md"]))
    end

    test "rejects name with slashes" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{name: "skills/nested"})

      assert {:error, msg} = CreateSkill.run(params, context)
      assert msg =~ "dangerous characters"
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

    test "allows consecutive hyphens" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{name: "my--tool"})

      assert {:ok, _} = CreateSkill.run(params, context)
    end

    test "rejects name with backslash" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{name: "bad\\name"})

      assert {:error, msg} = CreateSkill.run(params, context)
      assert msg =~ "dangerous characters"
    end
  end

  describe "run/2 — description validation" do
    test "rejects description with newlines" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{description: "line one\nline two"})

      assert {:error, "description must be a single line"} = CreateSkill.run(params, context)
    end

    test "rejects description exceeding max length" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{description: String.duplicate("a", 1025)})

      assert {:error, "description too long" <> _} = CreateSkill.run(params, context)
    end

    test "accepts description at exactly max length" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{description: String.duplicate("a", 1024)})

      assert {:ok, _} = CreateSkill.run(params, context)
    end
  end

  describe "run/2 — content validation" do
    test "rejects content exceeding max size" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{content: String.duplicate("a", 1_048_577)})

      assert {:error, "content too large" <> _} = CreateSkill.run(params, context)
    end
  end

  describe "run/2 — metadata validation" do
    test "rejects metadata keys with special characters" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{metadata: %{"bad-key" => "value"}})

      assert {:error, "invalid metadata key: bad-key" <> _} = CreateSkill.run(params, context)
    end

    test "rejects metadata values with newlines" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{metadata: %{"key" => "line1\nline2"}})

      assert {:error, "invalid metadata value for key" <> _} = CreateSkill.run(params, context)
    end

    test "accepts metadata with atom keys" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{metadata: %{author: "test"}})

      assert {:ok, _} = CreateSkill.run(params, context)
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
    test "falls back to Config.workspace when workspace not in context" do
      context = %{state: %{}}

      params = %{
        valid_params()
        | name: "fallback-test-skill-#{System.unique_integer([:positive])}"
      }

      config_workspace = Goodwizard.Config.workspace()
      skill_dir = Path.join([config_workspace, "skills", params.name])

      on_exit(fn -> File.rm_rf!(skill_dir) end)

      assert {:ok, %{path: path}} = CreateSkill.run(params, context)
      assert String.starts_with?(path, config_workspace)
    end
  end

  describe "run/2 — file system error paths" do
    test "returns error when directory creation fails" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      # Create a file where the skills directory should be, blocking mkdir_p
      skills_path = Path.join([workspace, "skills", "my-tool"])
      File.mkdir_p!(Path.dirname(skills_path))
      File.write!(skills_path, "blocker")

      context = context_with_workspace(workspace)
      params = valid_params()

      assert {:error, "failed to create skill directory: " <> _} =
               CreateSkill.run(params, context)
    end

    test "returns error when file write fails" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      # Create the skill dir, then make it read-only so File.write fails
      skill_dir = Path.join([workspace, "skills", "write-fail"])
      File.mkdir_p!(skill_dir)
      File.chmod!(skill_dir, 0o444)
      on_exit(fn -> File.chmod!(skill_dir, 0o755) end)

      context = context_with_workspace(workspace)
      params = valid_params(%{name: "write-fail"})

      assert {:error, "failed to write skill: " <> _} = CreateSkill.run(params, context)
    end
  end
end
