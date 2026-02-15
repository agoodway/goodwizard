defmodule Goodwizard.Plugins.PromptSkillsTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Plugins.PromptSkills

  defp create_skill_dir(base, name, opts \\ []) do
    dir = Path.join(base, name)
    File.mkdir_p!(dir)

    frontmatter = Keyword.get(opts, :frontmatter, %{name: name, description: "#{name} skill"})
    body = Keyword.get(opts, :body, "# #{name}\n\nSkill instructions.")
    resources = Keyword.get(opts, :resources, [])

    yaml_lines =
      Enum.map_join(frontmatter, "\n", fn {k, v} -> "#{k}: #{v}" end)

    content = "---\n#{yaml_lines}\n---\n#{body}"
    File.write!(Path.join(dir, "SKILL.md"), content)

    Enum.each(resources, fn {filename, file_content} ->
      File.write!(Path.join(dir, filename), file_content)
    end)

    dir
  end

  defp tmp_workspace do
    dir = Path.join(System.tmp_dir!(), "prompt_skills_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end

  describe "scan_skills/1" do
    test "finds SKILL.md files in workspace/skills/" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      skills_dir = Path.join(workspace, "skills")
      File.mkdir_p!(skills_dir)
      create_skill_dir(skills_dir, "search")
      create_skill_dir(skills_dir, "deploy")

      skills = PromptSkills.scan_skills(workspace)
      names = Enum.map(skills, & &1.name)
      assert "deploy" in names
      assert "search" in names
      assert length(skills) == 2
    end

    test "returns empty list when directory does not exist" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      skills = PromptSkills.scan_skills(workspace)
      assert skills == []
    end

    test "returns empty list for empty skill directories" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      File.mkdir_p!(Path.join(workspace, "skills"))

      skills = PromptSkills.scan_skills(workspace)
      assert skills == []
    end

    test "ignores subdirectory without SKILL.md" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      skills_dir = Path.join(workspace, "skills")
      File.mkdir_p!(Path.join(skills_dir, "drafts"))
      create_skill_dir(skills_dir, "search")

      skills = PromptSkills.scan_skills(workspace)
      assert length(skills) == 1
      assert hd(skills).name == "search"
    end

    test "indexes resource files per skill" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      skills_dir = Path.join(workspace, "skills")
      File.mkdir_p!(skills_dir)

      create_skill_dir(skills_dir, "deploy",
        resources: [{"deploy.sh", "#!/bin/bash"}, {"config.template", "key=value"}]
      )

      skills = PromptSkills.scan_skills(workspace)
      assert length(skills) == 1
      assert hd(skills).resources == ["config.template", "deploy.sh"]
    end

    test "skips skills with malformed frontmatter" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      skills_dir = Path.join(workspace, "skills")
      File.mkdir_p!(skills_dir)

      # Valid skill
      create_skill_dir(skills_dir, "search")

      # Malformed skill - write directly
      bad_dir = Path.join(skills_dir, "broken")
      File.mkdir_p!(bad_dir)
      File.write!(Path.join(bad_dir, "SKILL.md"), "---\nname: [invalid\n---\nBody")

      skills = PromptSkills.scan_skills(workspace)
      assert length(skills) == 1
      assert hd(skills).name == "search"
    end

    test "skips oversized SKILL.md files" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      skills_dir = Path.join(workspace, "skills")
      File.mkdir_p!(skills_dir)

      # Valid skill
      create_skill_dir(skills_dir, "small")

      # Oversized skill (> 256KB)
      big_dir = Path.join(skills_dir, "big")
      File.mkdir_p!(big_dir)

      big_content =
        "---\nname: big\ndescription: big skill\n---\n" <> String.duplicate("x", 300_000)

      File.write!(Path.join(big_dir, "SKILL.md"), big_content)

      skills = PromptSkills.scan_skills(workspace)
      assert length(skills) == 1
      assert hd(skills).name == "small"
    end

    test "skills are sorted alphabetically by name" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      skills_dir = Path.join(workspace, "skills")
      File.mkdir_p!(skills_dir)
      create_skill_dir(skills_dir, "zebra")
      create_skill_dir(skills_dir, "alpha")
      create_skill_dir(skills_dir, "middle")

      skills = PromptSkills.scan_skills(workspace)
      names = Enum.map(skills, & &1.name)
      assert names == ["alpha", "middle", "zebra"]
    end
  end

  describe "build_skills_summary/1" do
    test "returns empty string for no skills" do
      assert PromptSkills.build_skills_summary([]) == ""
    end

    test "formats skills with descriptions" do
      skills = [
        %{name: "deploy", description: "Deploy to production", resources: []},
        %{name: "search", description: "Search the web", resources: []}
      ]

      summary = PromptSkills.build_skills_summary(skills)
      assert summary =~ "## Available Skills"
      assert summary =~ "activate_skill"
      assert summary =~ "- **deploy** - Deploy to production"
      assert summary =~ "- **search** - Search the web"
    end

    test "includes resource filenames" do
      skills = [
        %{
          name: "deploy",
          description: "Deploy to production",
          resources: ["config.template", "deploy.sh"]
        }
      ]

      summary = PromptSkills.build_skills_summary(skills)
      assert summary =~ "Resources: config.template, deploy.sh"
    end

    test "omits resources line when no resources" do
      skills = [
        %{name: "search", description: "Search the web", resources: []}
      ]

      summary = PromptSkills.build_skills_summary(skills)
      refute summary =~ "Resources:"
    end
  end

  describe "mount/2" do
    test "initializes with scanned skills and summary" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      skills_dir = Path.join(workspace, "skills")
      File.mkdir_p!(skills_dir)
      create_skill_dir(skills_dir, "search")

      agent = %{state: %{workspace: workspace}}
      {:ok, state} = PromptSkills.mount(agent, %{})

      assert length(state.skills) == 1
      assert hd(state.skills).name == "search"
      assert state.skills_summary =~ "## Available Skills"
      assert state.skills_summary =~ "**search**"
    end

    test "initializes empty when no skills exist" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      agent = %{state: %{workspace: workspace}}
      {:ok, state} = PromptSkills.mount(agent, %{})

      assert state.skills == []
      assert state.skills_summary == ""
    end

    test "skips invalid skills gracefully" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      skills_dir = Path.join(workspace, "skills")
      File.mkdir_p!(skills_dir)

      # Two valid, one invalid
      create_skill_dir(skills_dir, "alpha")
      create_skill_dir(skills_dir, "beta")

      bad_dir = Path.join(skills_dir, "broken")
      File.mkdir_p!(bad_dir)
      File.write!(Path.join(bad_dir, "SKILL.md"), "no frontmatter here")

      agent = %{state: %{workspace: workspace}}
      {:ok, state} = PromptSkills.mount(agent, %{})

      assert length(state.skills) == 2
    end

    test "accepts workspace from config override" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      skills_dir = Path.join(workspace, "skills")
      File.mkdir_p!(skills_dir)
      create_skill_dir(skills_dir, "from-config")

      # Agent state has a different workspace, but config overrides it
      agent = %{state: %{workspace: "/nonexistent"}}
      {:ok, state} = PromptSkills.mount(agent, %{workspace: workspace})

      assert length(state.skills) == 1
      assert hd(state.skills).name == "from-config"
    end

    test "defaults to current directory when no workspace provided" do
      agent = %{state: %{}}
      {:ok, state} = PromptSkills.mount(agent, %{})

      # Should not crash, just return empty or whatever skills exist in "."
      assert is_list(state.skills)
    end
  end
end
