defmodule Goodwizard.Actions.Skills.ActivateSkillTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Skills.ActivateSkill

  defp context_with_skills(skills) do
    %{state: %{prompt_skills: %{skills: skills}}}
  end

  describe "run/2" do
    test "returns body for valid skill name" do
      skills = [
        %{name: "deploy", content: "# Deploy\n\nRun the deployment.", resources: []},
        %{name: "search", content: "# Search\n\nSearch docs.", resources: []}
      ]

      context = context_with_skills(skills)
      assert {:ok, %{content: content}} = ActivateSkill.run(%{name: "deploy"}, context)
      assert content == "# Deploy\n\nRun the deployment."
    end

    test "returns error for unknown skill name" do
      context = context_with_skills([%{name: "deploy", content: "body", resources: []}])

      assert {:error, "skill not found: nonexistent"} =
               ActivateSkill.run(%{name: "nonexistent"}, context)
    end

    test "returns error when no skills in state" do
      context = %{state: %{prompt_skills: %{skills: []}}}

      assert {:error, "skill not found: anything"} =
               ActivateSkill.run(%{name: "anything"}, context)
    end

    test "returns error when prompt_skills not in state" do
      context = %{state: %{}}
      assert {:error, "skill not found: test"} = ActivateSkill.run(%{name: "test"}, context)
    end
  end
end
