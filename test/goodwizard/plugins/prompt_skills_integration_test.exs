defmodule Goodwizard.Plugins.PromptSkillsIntegrationTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Plugins.PromptSkills
  alias Goodwizard.Actions.Skills.ActivateSkill
  alias Goodwizard.Actions.Skills.LoadSkillResource
  alias Goodwizard.Character.Hydrator

  defp tmp_workspace do
    dir =
      Path.join(
        System.tmp_dir!(),
        "prompt_skills_integration_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    dir
  end

  defp create_skill(skills_dir, name, body, resources \\ []) do
    dir = Path.join(skills_dir, name)
    File.mkdir_p!(dir)

    content = "---\nname: #{name}\ndescription: #{name} skill description\n---\n#{body}"
    File.write!(Path.join(dir, "SKILL.md"), content)

    Enum.each(resources, fn {filename, file_content} ->
      File.write!(Path.join(dir, filename), file_content)
    end)
  end

  describe "end-to-end skill pipeline" do
    test "scan -> mount -> activate -> hydrate with active skill content" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      skills_dir = Path.join(workspace, "skills")
      File.mkdir_p!(skills_dir)

      create_skill(skills_dir, "deploy", "# Deploy\n\nRun deployment commands.")
      create_skill(skills_dir, "search", "# Search\n\nSearch documentation.",
        [{"config.yaml", "timeout: 30"}])

      # Step 1: Mount plugin (scan + build summary)
      agent = %{state: %{workspace: workspace}}
      {:ok, plugin_state} = PromptSkills.mount(agent, %{})

      assert length(plugin_state.skills) == 2
      assert plugin_state.skills_summary =~ "deploy"
      assert plugin_state.skills_summary =~ "search"

      # Step 2: Activate a skill
      context = %{state: %{prompt_skills: plugin_state}}
      {:ok, %{content: activated_content}} = ActivateSkill.run(%{name: "deploy"}, context)
      assert activated_content =~ "Run deployment commands"

      # Step 3: Load a resource from a different skill
      {:ok, %{content: resource_content}} =
        LoadSkillResource.run(%{skill_name: "search", resource: "config.yaml"}, context)

      assert resource_content == "timeout: 30"

      # Step 4: Hydrate prompt with skills summary
      skills_state = %{summary: plugin_state.skills_summary}
      {:ok, prompt} = Hydrator.hydrate(workspace, skills: skills_state)

      assert prompt =~ "deploy"
      assert prompt =~ "search"
      assert prompt =~ "activate_skill"
    end

    test "scan -> mount -> activate -> hydrate with active skill injection" do
      workspace = tmp_workspace()
      on_exit(fn -> File.rm_rf!(workspace) end)

      skills_dir = Path.join(workspace, "skills")
      File.mkdir_p!(skills_dir)

      create_skill(skills_dir, "test-skill", "# Test Skill\n\nSpecialized instructions.")

      # Mount
      agent = %{state: %{workspace: workspace}}
      {:ok, plugin_state} = PromptSkills.mount(agent, %{})

      # Activate
      context = %{state: %{prompt_skills: plugin_state}}
      {:ok, %{content: content}} = ActivateSkill.run(%{name: "test-skill"}, context)

      # Hydrate with active skill content
      skills_state = %{
        summary: plugin_state.skills_summary,
        active: [%{name: "test-skill", content: content}]
      }

      {:ok, prompt} = Hydrator.hydrate(workspace, skills: skills_state)

      assert prompt =~ "Specialized instructions"
      assert prompt =~ "test-skill"
    end
  end
end
