defmodule Goodwizard.CharacterTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Character

  describe "new/0" do
    test "produces a valid character struct with expected defaults" do
      {:ok, character} = Character.new()

      assert character.name == "Goodwizard"
      assert character.description == "Personal AI assistant"
      assert character.identity.role == "personal AI assistant"
    end

    test "includes personality traits and values" do
      {:ok, character} = Character.new()

      assert character.personality.traits == ["analytical", "patient", "thorough"]
      assert character.personality.values == ["accuracy", "helpfulness", "safety"]
    end

    test "includes voice with tone and style" do
      {:ok, character} = Character.new()

      assert character.voice.tone == :friendly
      assert character.voice.style == "concise technical"
    end

    test "includes instructions" do
      {:ok, character} = Character.new()

      assert is_list(character.instructions)
      assert length(character.instructions) > 0
      assert "Read files before editing them" in character.instructions
    end

    test "has an id" do
      {:ok, character} = Character.new()
      assert is_binary(character.id)
    end
  end

  describe "new/1 with overrides" do
    test "allows overriding name" do
      {:ok, character} = Character.new(%{name: "TestWizard"})
      assert character.name == "TestWizard"
    end
  end
end
