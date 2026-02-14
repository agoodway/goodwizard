defmodule Goodwizard.Actions.Skills.ActivateSkill do
  @moduledoc """
  Loads a skill's full SKILL.md body (Tier 2 content) by name.

  Looks up the skill in the agent's prompt_skills state and returns
  the frontmatter-stripped body content for injection into the conversation.
  """

  use Jido.Action,
    name: "activate_skill",
    description:
      "Load a skill's full instructions for the current conversation. Use when a discovered skill is relevant to the user's request.",
    schema: [
      name: [type: :string, required: true, doc: "The skill name to activate"]
    ]

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(%{name: name} = _params, context) do
    skills = get_in(context, [:state, :prompt_skills, :skills]) || []

    case Enum.find(skills, &(&1.name == name)) do
      nil -> {:error, "skill not found: #{name}"}
      skill -> {:ok, %{content: skill.content}}
    end
  end
end
