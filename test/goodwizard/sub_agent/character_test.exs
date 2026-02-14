defmodule Goodwizard.SubAgent.CharacterTest do
  use ExUnit.Case, async: true

  alias Goodwizard.SubAgent.Character

  describe "character definition" do
    test "creates character with focused identity" do
      {:ok, character} = Character.new()

      assert character.name == "Goodwizard SubAgent"
      assert character.identity.role == "background research and file processing agent"
    end

    test "has professional tone" do
      {:ok, character} = Character.new()

      assert character.voice.tone == :professional
      assert character.voice.style == "concise and factual"
    end

    test "has constrained instructions" do
      {:ok, character} = Character.new()

      instructions = character.instructions

      assert "Complete the assigned task and report results" in instructions
      assert "Do not communicate directly with the user" in instructions
      assert "Do not spawn additional subagents" in instructions
      assert "Stay within the scope of the delegated task" in instructions
      assert "Read files before modifying them" in instructions
    end

    test "has focused personality traits" do
      {:ok, character} = Character.new()

      assert "focused" in character.personality.traits
      assert "efficient" in character.personality.traits
      assert "thorough" in character.personality.traits
    end

    test "renders to system prompt" do
      {:ok, character} = Character.new()
      prompt = Jido.Character.to_system_prompt(character)

      assert is_binary(prompt)
      assert prompt =~ "background research and file processing agent"
      assert prompt =~ "Do not spawn additional subagents"
    end
  end

  describe "on_before_cmd task context injection" do
    test "injects task context as knowledge into character" do
      {:ok, character} = Character.new()

      {:ok, character} =
        Jido.Character.add_knowledge(character, "Research the Elixir GenServer pattern",
          category: "task-context"
        )

      prompt = Jido.Character.to_system_prompt(character)

      assert prompt =~ "Research the Elixir GenServer pattern"
    end
  end
end
