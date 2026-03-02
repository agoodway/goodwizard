defmodule Goodwizard.Character.Hydrator do
  @moduledoc """
  Stateless coordinator that enriches the base character with runtime state.

  Reconstructs the character fresh each turn from file-based state, injects
  bootstrap files, memory, and skills, then renders to a system prompt string.
  """

  require Logger

  alias Goodwizard.Brain.Schema
  alias Goodwizard.Character.Preamble

  @bootstrap_files ~w(AGENTS.md SOUL.md USER.md TOOLS.md IDENTITY.md)
  @max_bootstrap_file_bytes 1_048_576

  @valid_tones ~w(formal casual playful serious warm cold professional friendly)

  @doc """
  Hydrate a character with workspace context and optional enrichments.

  Creates the base character from `Goodwizard.Character` defaults, applies
  config overrides from the `[character]` TOML section, injects bootstrap
  files from the workspace as knowledge, and renders to a system prompt string.

  ## Options

    * `:memory` - Memory content string to inject as long-term-memory knowledge
    * `:memory_context` - Episodic/procedural context string to inject into prompt
    * `:skills` - Skills state map with `:summary` and optional `:active` list
    * `:config_overrides` - Map of character overrides (normally from Config)
  """
  @spec hydrate(String.t(), keyword()) :: {:ok, String.t()}
  def hydrate(workspace, opts \\ []) do
    {:ok, character} = Goodwizard.Character.new()

    config_overrides = Keyword.get(opts, :config_overrides) || load_config_overrides()

    character =
      character
      |> apply_config_overrides(config_overrides)
      |> inject_bootstrap_files(workspace)
      |> inject_brain_awareness(workspace)
      |> maybe_inject_memory(Keyword.get(opts, :memory))
      |> maybe_inject_memory_context(Keyword.get(opts, :memory_context))
      |> maybe_inject_skills(Keyword.get(opts, :skills))

    rendered = Jido.Character.to_system_prompt(character)
    {:ok, Preamble.generate() <> "\n\n" <> rendered}
  end

  @doc """
  Add memory content as knowledge with category "long-term-memory".
  """
  @spec inject_memory(Jido.Character.t(), String.t()) :: Jido.Character.t()
  def inject_memory(character, memory_content) when is_binary(memory_content) do
    {:ok, character} =
      Jido.Character.add_knowledge(character, memory_content, category: "long-term-memory")

    character
  end

  @doc """
  Add skills summary as instruction and active skill content as knowledge.

  ## Skills State

    * `:summary` - String summary of available skills (added as instruction)
    * `:active` - List of `%{name: String.t(), content: String.t()}` maps
      for currently activated skills (added as knowledge with category "active-skill")
  """
  @spec inject_skills(Jido.Character.t(), map()) :: Jido.Character.t()
  def inject_skills(character, %{} = skills_state) do
    character =
      case Map.get(skills_state, :summary) do
        nil ->
          character

        "" ->
          character

        summary ->
          {:ok, character} = Jido.Character.add_instruction(character, summary)
          character
      end

    case Map.get(skills_state, :active) do
      nil ->
        character

      active when is_list(active) ->
        Enum.reduce(active, character, fn skill, acc ->
          name = Map.get(skill, :name, "unknown")
          content = Map.get(skill, :content, "")
          labeled_content = "[Skill: #{name}]\n#{content}"

          {:ok, acc} =
            Jido.Character.add_knowledge(acc, labeled_content, category: "active-skill")

          acc
        end)

      _other ->
        character
    end
  end

  @doc """
  Injects knowledge base awareness instructions based on available entity types.

  Reads schema summaries (cached with 5-minute TTL), builds an instruction
  describing available entity types and when to create entities, and adds
  it to the character. Returns character unchanged if no types exist.
  """
  @spec inject_brain_awareness(Jido.Character.t(), String.t()) :: Jido.Character.t()
  def inject_brain_awareness(character, workspace) do
    case cached_schema_summaries(workspace) do
      [] ->
        character

      summaries ->
        instruction = build_brain_instruction(summaries)
        {:ok, character} = Jido.Character.add_instruction(character, instruction)
        character
    end
  end

  defp build_brain_instruction(summaries) do
    type_lines =
      Enum.map_join(summaries, "\n", fn s ->
        fields = Enum.join(s.required ++ s.optional, ", ")
        "- **#{s.title}** (`#{s.type}`): #{fields}"
      end)

    """
    ## Knowledge Base — Proactive Entity Extraction

    When the user mentions people, companies, events, or other notable entities \
    in conversation, proactively extract and save them using `create_entity`. \
    Do not wait for the user to explicitly ask you to save information.

    Available entity types:
    #{type_lines}

    For each recognized entity, call `create_entity` with the matching type and \
    fill in as many fields as you can infer from context.\
    """
  end

  defp cached_schema_summaries(workspace) do
    cache_key = "knowledge_base:schema_summaries:#{workspace}"

    case Goodwizard.Cache.get(cache_key) do
      nil ->
        case Schema.summarize_types(workspace) do
          {:ok, summaries} ->
            Goodwizard.Cache.put(cache_key, summaries, ttl: :timer.minutes(5))
            summaries

          {:error, _} ->
            []
        end

      summaries ->
        summaries
    end
  end

  # Private

  defp load_config_overrides do
    Goodwizard.Config.get(:character)
  catch
    :exit, _ -> nil
  end

  defp apply_config_overrides(character, nil), do: character

  defp apply_config_overrides(character, overrides) when is_map(overrides) do
    updates = %{}

    updates =
      if name = Map.get(overrides, "name"),
        do: Map.put(updates, :name, name),
        else: updates

    updates =
      case Map.get(overrides, "tone") do
        nil ->
          updates

        tone when tone in @valid_tones ->
          voice = Map.get(character, :voice, %{})
          Map.put(updates, :voice, Map.put(voice, :tone, String.to_existing_atom(tone)))

        invalid_tone ->
          Logger.warning("Invalid tone #{inspect(invalid_tone)}, ignoring")
          updates
      end

    updates =
      if style = Map.get(overrides, "style") do
        voice = Map.get(updates, :voice, Map.get(character, :voice, %{}))
        Map.put(updates, :voice, Map.put(voice, :style, style))
      else
        updates
      end

    updates =
      if traits = Map.get(overrides, "traits") do
        personality = Map.get(character, :personality, %{})
        Map.put(updates, :personality, Map.put(personality, :traits, traits))
      else
        updates
      end

    if map_size(updates) == 0 do
      character
    else
      {:ok, character} = Jido.Character.update(character, updates)
      character
    end
  end

  defp inject_bootstrap_files(character, workspace) do
    Enum.reduce(@bootstrap_files, character, fn filename, acc ->
      path = Path.join(workspace, filename)

      with {:ok, %{size: size}} <- File.stat(path),
           true <- size <= @max_bootstrap_file_bytes,
           {:ok, content} <- File.read(path) do
        {:ok, acc} = Jido.Character.add_knowledge(acc, content, category: "workspace")
        acc
      else
        false ->
          Logger.warning(
            "Bootstrap file #{filename} exceeds #{@max_bootstrap_file_bytes} byte limit, skipping"
          )

          acc

        {:error, _} ->
          acc
      end
    end)
  end

  defp maybe_inject_memory(character, nil), do: character
  defp maybe_inject_memory(character, ""), do: character
  defp maybe_inject_memory(character, memory), do: inject_memory(character, memory)

  defp maybe_inject_memory_context(character, nil), do: character
  defp maybe_inject_memory_context(character, ""), do: character

  defp maybe_inject_memory_context(character, context) when is_binary(context) do
    labeled = "## Conversation Start Memory Context\n\n" <> context

    {:ok, character} =
      Jido.Character.add_knowledge(character, labeled, category: "memory-context")

    character
  end

  defp maybe_inject_skills(character, nil), do: character

  defp maybe_inject_skills(_character, skills) when is_binary(skills) do
    raise ArgumentError, ":skills must be a map, got a string"
  end

  defp maybe_inject_skills(character, skills), do: inject_skills(character, skills)
end
