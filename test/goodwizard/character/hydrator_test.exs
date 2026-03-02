defmodule Goodwizard.Character.HydratorTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Brain.Schema
  alias Goodwizard.Cache
  alias Goodwizard.Character.{Hydrator, Preamble}

  setup do
    workspace = Path.join(System.tmp_dir!(), "hydrator_test_#{:rand.uniform(100_000)}")
    File.mkdir_p!(workspace)
    on_cleanup(fn -> File.rm_rf!(workspace) end)
    %{workspace: workspace}
  end

  defp on_cleanup(fun), do: ExUnit.Callbacks.on_exit(fun)

  describe "hydrate/2 bootstrap files" do
    test "loads bootstrap files from workspace as knowledge", %{workspace: workspace} do
      File.write!(Path.join(workspace, "SOUL.md"), "I am a helpful assistant.")
      File.write!(Path.join(workspace, "TOOLS.md"), "Available tools: read_file, write_file")

      {:ok, prompt} = Hydrator.hydrate(workspace)

      assert prompt =~ "I am a helpful assistant."
      assert prompt =~ "Available tools: read_file, write_file"
    end

    test "silently skips missing bootstrap files", %{workspace: workspace} do
      # No bootstrap files exist
      {:ok, prompt} = Hydrator.hydrate(workspace)

      # Should still produce a valid prompt with at least the character info
      assert prompt =~ "Goodwizard"
    end

    test "includes all present bootstrap files", %{workspace: workspace} do
      File.write!(Path.join(workspace, "AGENTS.md"), "Agent config here")
      File.write!(Path.join(workspace, "SOUL.md"), "Soul content here")
      File.write!(Path.join(workspace, "USER.md"), "User prefs here")
      File.write!(Path.join(workspace, "TOOLS.md"), "Tools list here")
      File.write!(Path.join(workspace, "IDENTITY.md"), "Identity info here")

      {:ok, prompt} = Hydrator.hydrate(workspace)

      assert prompt =~ "Agent config here"
      assert prompt =~ "Soul content here"
      assert prompt =~ "User prefs here"
      assert prompt =~ "Tools list here"
      assert prompt =~ "Identity info here"
    end
  end

  describe "hydrate/2 preamble" do
    test "system prompt starts with preamble content", %{workspace: workspace} do
      {:ok, prompt} = Hydrator.hydrate(workspace)
      preamble = Preamble.generate()

      assert String.starts_with?(prompt, preamble)
    end

    test "preamble is separated from character content by a blank line", %{workspace: workspace} do
      {:ok, prompt} = Hydrator.hydrate(workspace)
      preamble = Preamble.generate()

      # After removing the preamble, the remaining content should start with "\n\n"
      rest = String.replace_prefix(prompt, preamble, "")
      assert String.starts_with?(rest, "\n\n")
    end

    test "character content follows the preamble", %{workspace: workspace} do
      {:ok, prompt} = Hydrator.hydrate(workspace)

      assert prompt =~ "System Orientation"
      assert prompt =~ "Goodwizard"

      # Preamble comes before character name
      preamble_pos = :binary.match(prompt, "System Orientation") |> elem(0)
      character_pos = :binary.match(prompt, "Goodwizard") |> elem(0)
      assert preamble_pos < character_pos
    end
  end

  describe "hydrate/2 config overrides" do
    test "applies name override", %{workspace: workspace} do
      {:ok, prompt} =
        Hydrator.hydrate(workspace, config_overrides: %{"name" => "CustomWizard"})

      assert prompt =~ "CustomWizard"
    end

    test "applies tone override", %{workspace: workspace} do
      {:ok, prompt} =
        Hydrator.hydrate(workspace, config_overrides: %{"tone" => "formal"})

      assert prompt =~ "Formal"
    end

    test "applies style override", %{workspace: workspace} do
      {:ok, prompt} =
        Hydrator.hydrate(workspace, config_overrides: %{"style" => "verbose academic"})

      assert prompt =~ "verbose academic"
    end

    test "applies traits override", %{workspace: workspace} do
      {:ok, prompt} =
        Hydrator.hydrate(workspace, config_overrides: %{"traits" => ["creative", "bold"]})

      assert prompt =~ "creative"
      assert prompt =~ "bold"
    end

    test "handles nil config overrides", %{workspace: workspace} do
      {:ok, prompt} = Hydrator.hydrate(workspace, config_overrides: nil)
      assert prompt =~ "Goodwizard"
    end

    test "invalid tone does not prevent valid overrides from applying", %{workspace: workspace} do
      {:ok, prompt} =
        Hydrator.hydrate(workspace,
          config_overrides: %{"name" => "CustomWizard", "tone" => "sarcastic"}
        )

      assert prompt =~ "CustomWizard"
    end

    test "applies all overrides together", %{workspace: workspace} do
      {:ok, prompt} =
        Hydrator.hydrate(workspace,
          config_overrides: %{
            "name" => "CombinedWizard",
            "tone" => "formal",
            "style" => "verbose academic",
            "traits" => ["creative", "bold"]
          }
        )

      assert prompt =~ "CombinedWizard"
      assert prompt =~ "Formal"
      assert prompt =~ "verbose academic"
      assert prompt =~ "creative"
      assert prompt =~ "bold"
    end
  end

  describe "hydrate/2 renders to system prompt string" do
    test "returns a string via to_system_prompt", %{workspace: workspace} do
      {:ok, prompt} = Hydrator.hydrate(workspace)

      assert is_binary(prompt)
      assert prompt =~ "Goodwizard"
      assert prompt =~ "analytical"
    end
  end

  describe "inject_memory/2" do
    test "adds knowledge with category long-term-memory" do
      {:ok, character} = Goodwizard.Character.new()

      character = Hydrator.inject_memory(character, "User prefers dark mode")

      knowledge = Map.get(character, :knowledge, [])

      assert Enum.any?(knowledge, fn k ->
               k.content == "User prefers dark mode" && k.category == "long-term-memory"
             end)
    end
  end

  describe "inject_skills/2" do
    test "adds skills summary as instruction" do
      {:ok, character} = Goodwizard.Character.new()

      character = Hydrator.inject_skills(character, %{summary: "Available: search, edit"})

      assert "Available: search, edit" in character.instructions
    end

    test "adds active skill content as knowledge with skill name" do
      {:ok, character} = Goodwizard.Character.new()

      character =
        Hydrator.inject_skills(character, %{
          summary: "Skills available",
          active: [
            %{name: "search", content: "Search tool documentation"}
          ]
        })

      knowledge = Map.get(character, :knowledge, [])

      assert Enum.any?(knowledge, fn k ->
               k.content =~ "Search tool documentation" &&
                 k.content =~ "[Skill: search]" &&
                 k.category == "active-skill"
             end)
    end

    test "handles empty skills state" do
      {:ok, character} = Goodwizard.Character.new()

      result = Hydrator.inject_skills(character, %{})
      assert result.name == "Goodwizard"
    end

    test "handles non-list :active value gracefully" do
      {:ok, character} = Goodwizard.Character.new()

      result = Hydrator.inject_skills(character, %{active: "not a list"})
      assert result.name == "Goodwizard"

      result = Hydrator.inject_skills(character, %{active: 123})
      assert result.name == "Goodwizard"
    end
  end

  describe "hydrate/2 with memory option" do
    test "includes memory in system prompt", %{workspace: workspace} do
      {:ok, prompt} =
        Hydrator.hydrate(workspace, memory: "User likes concise answers")

      assert prompt =~ "User likes concise answers"
    end

    test "skips empty memory", %{workspace: workspace} do
      {:ok, prompt1} = Hydrator.hydrate(workspace)
      {:ok, prompt2} = Hydrator.hydrate(workspace, memory: "")

      # Both should be the same (empty memory not injected)
      assert prompt1 == prompt2
    end
  end

  describe "inject_knowledge_base_awareness/2" do
    setup %{workspace: workspace} do
      schemas_dir = Path.join([workspace, "knowledge_base", "schemas"])
      File.mkdir_p!(schemas_dir)
      %{schemas_dir: schemas_dir}
    end

    test "adds instruction with entity types when schemas exist", %{workspace: workspace} do
      schema = %{
        "$schema" => "http://json-schema.org/draft-07/schema#",
        "title" => "Person",
        "type" => "object",
        "required" => ["id", "name"],
        "properties" => %{
          "id" => %{"type" => "string"},
          "name" => %{"type" => "string"},
          "email" => %{"type" => "string"}
        }
      }

      Schema.save(workspace, "people", schema)
      # Clear any cached value from prior tests
      Cache.delete("knowledge_base:schema_summaries:#{workspace}")

      {:ok, character} = Goodwizard.Character.new()
      character = Hydrator.inject_brain_awareness(character, workspace)

      instruction = List.last(character.instructions)
      assert instruction =~ "Proactive Entity Extraction"
      assert instruction =~ "Person"
      assert instruction =~ "people"
      assert instruction =~ "name"
      assert instruction =~ "create_entity"
    end

    test "returns character unchanged when no schemas exist", %{workspace: workspace} do
      # schemas dir exists but is empty — clear cache
      Cache.delete("knowledge_base:schema_summaries:#{workspace}")

      {:ok, character} = Goodwizard.Character.new()
      original_instructions = character.instructions
      character = Hydrator.inject_brain_awareness(character, workspace)

      assert character.instructions == original_instructions
    end

    test "returns character unchanged when knowledge base dir missing" do
      workspace = Path.join(System.tmp_dir!(), "no_kb_#{:rand.uniform(100_000)}")
      on_cleanup(fn -> File.rm_rf!(workspace) end)
      Cache.delete("knowledge_base:schema_summaries:#{workspace}")

      {:ok, character} = Goodwizard.Character.new()
      original_instructions = character.instructions
      character = Hydrator.inject_brain_awareness(character, workspace)

      assert character.instructions == original_instructions
    end
  end

  describe "hydrate/2 with knowledge base awareness" do
    test "includes entity types in system prompt when schemas exist", %{workspace: workspace} do
      schemas_dir = Path.join([workspace, "knowledge_base", "schemas"])
      File.mkdir_p!(schemas_dir)

      schema = %{
        "$schema" => "http://json-schema.org/draft-07/schema#",
        "title" => "Meeting",
        "type" => "object",
        "required" => ["id", "title", "date"],
        "properties" => %{
          "id" => %{"type" => "string"},
          "title" => %{"type" => "string"},
          "date" => %{"type" => "string"},
          "notes" => %{"type" => "string"}
        }
      }

      Schema.save(workspace, "meetings", schema)
      Cache.delete("knowledge_base:schema_summaries:#{workspace}")

      {:ok, prompt} = Hydrator.hydrate(workspace)

      assert prompt =~ "Proactive Entity Extraction"
      assert prompt =~ "Meeting"
      assert prompt =~ "meetings"
    end

    test "omits knowledge base awareness section when no knowledge base dir exists", %{workspace: workspace} do
      Cache.delete("knowledge_base:schema_summaries:#{workspace}")

      {:ok, prompt} = Hydrator.hydrate(workspace)

      refute prompt =~ "Proactive Entity Extraction"
    end
  end

  describe "hydrate/2 with skills option" do
    test "includes skills in system prompt", %{workspace: workspace} do
      {:ok, prompt} =
        Hydrator.hydrate(workspace,
          skills: %{
            summary: "Available skills: search, edit, run",
            active: [%{name: "search", content: "Search documentation"}]
          }
        )

      assert prompt =~ "Available skills: search, edit, run"
      assert prompt =~ "Search documentation"
    end

    test "omits skills section when no skills discovered", %{workspace: workspace} do
      {:ok, prompt} =
        Hydrator.hydrate(workspace,
          skills: %{summary: "", active: []}
        )

      refute prompt =~ "Available Skills"
    end

    test "omits skills section when skills option not provided", %{workspace: workspace} do
      {:ok, prompt} = Hydrator.hydrate(workspace)

      refute prompt =~ "Available Skills"
    end

    test "raises ArgumentError when skills passed as string", %{workspace: workspace} do
      assert_raise ArgumentError, ":skills must be a map, got a string", fn ->
        Hydrator.hydrate(workspace, skills: "some string")
      end
    end

    test "includes skills summary as instruction and active content as knowledge", %{
      workspace: workspace
    } do
      {:ok, prompt} =
        Hydrator.hydrate(workspace,
          skills: %{
            summary: "## Available Skills\n\n- **deploy** - Deploy to prod",
            active: [%{name: "deploy", content: "# Deploy\n\nRun deploy.sh"}]
          }
        )

      assert prompt =~ "## Available Skills"
      assert prompt =~ "**deploy**"
      assert prompt =~ "[Skill: deploy]"
      assert prompt =~ "Run deploy.sh"
    end
  end
end
