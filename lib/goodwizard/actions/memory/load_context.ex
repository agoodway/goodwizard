defmodule Goodwizard.Actions.Memory.LoadContext do
  @moduledoc """
  Loads relevant episodic and procedural memory context for prompt injection.
  """

  use Jido.Action,
    name: "load_memory_context",
    description:
      "Load recent and topic-relevant episodic/procedural memory and format it as markdown context",
    schema: [
      topic: [
        type: :string,
        required: false,
        default: "",
        doc: "Topic signal used to retrieve relevant episodes/procedures"
      ],
      max_episodes: [
        type: :integer,
        required: false,
        default: 5,
        doc: "Maximum number of episodes to include"
      ],
      max_procedures: [
        type: :integer,
        required: false,
        default: 3,
        doc: "Maximum number of procedures to include"
      ]
    ]

  require Logger

  alias Goodwizard.Actions.Memory.Helpers
  alias Goodwizard.Memory.Episodic
  alias Goodwizard.Memory.Procedural

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    memory_dir = Helpers.memory_dir(context)
    topic = Map.get(params, :topic, "") |> String.trim()
    max_episodes = Map.get(params, :max_episodes, 5)
    max_procedures = Map.get(params, :max_procedures, 3)

    with {:ok, episodes} <- load_episodes(memory_dir, topic, max_episodes),
         {:ok, procedures} <- load_procedures(memory_dir, topic, max_procedures) do
      memory_context = format_memory_context(episodes, procedures)

      {:ok,
       %{
         memory_context: memory_context,
         episodes_loaded: length(episodes),
         procedures_loaded: length(procedures)
       }}
    end
  end

  defp load_episodes(memory_dir, topic, max_episodes) do
    with {:ok, recent} <- Episodic.list(memory_dir, limit: 3),
         {:ok, relevant} <- maybe_search_relevant_episodes(memory_dir, topic, max_episodes) do
      merged =
        (recent ++ relevant)
        |> dedupe_by_id()
        |> Enum.take(max_episodes)

      {:ok, hydrate_episode_bodies(memory_dir, merged)}
    end
  end

  defp maybe_search_relevant_episodes(_memory_dir, "", _max_episodes), do: {:ok, []}

  defp maybe_search_relevant_episodes(memory_dir, topic, max_episodes) do
    Episodic.search(memory_dir, topic, limit: max_episodes)
  end

  defp hydrate_episode_bodies(memory_dir, episodes) do
    Enum.map(episodes, fn frontmatter ->
      body =
        case Episodic.read(memory_dir, frontmatter["id"]) do
          {:ok, {_fm, body}} -> body
          _ -> ""
        end

      %{frontmatter: frontmatter, body: body}
    end)
  end

  defp load_procedures(memory_dir, "", max_procedures) do
    with {:ok, all} <- Procedural.list(memory_dir, limit: 200) do
      sorted =
        all
        |> Enum.sort_by(fn procedure ->
          {-confidence_rank(procedure["confidence"]), -(procedure["usage_count"] || 0)}
        end)
        |> Enum.take(max_procedures)

      {:ok, hydrate_procedure_bodies(memory_dir, sorted)}
    end
  end

  defp load_procedures(memory_dir, topic, max_procedures) do
    with {:ok, procedures} <- Procedural.recall(memory_dir, topic, limit: max_procedures) do
      {:ok, hydrate_procedure_bodies(memory_dir, procedures)}
    end
  end

  defp hydrate_procedure_bodies(memory_dir, procedures) do
    Enum.map(procedures, fn frontmatter ->
      body =
        case Procedural.read(memory_dir, frontmatter["id"]) do
          {:ok, {_fm, body}} -> body
          _ -> ""
        end

      %{frontmatter: frontmatter, body: body}
    end)
  end

  defp dedupe_by_id(items) do
    {deduped, _seen} =
      Enum.reduce(items, {[], MapSet.new()}, fn item, {acc, seen} ->
        id = item["id"]

        if id in seen do
          {acc, seen}
        else
          {[item | acc], MapSet.put(seen, id)}
        end
      end)

    Enum.reverse(deduped)
  end

  defp confidence_rank("high"), do: 3
  defp confidence_rank("medium"), do: 2
  defp confidence_rank("low"), do: 1
  defp confidence_rank(_), do: 0

  defp format_memory_context([], []), do: ""

  defp format_memory_context(episodes, procedures) do
    [format_episodes(episodes), format_procedures(procedures)]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp format_episodes([]), do: ""

  defp format_episodes(episodes) do
    blocks =
      Enum.map_join(episodes, "\n\n", fn %{frontmatter: fm, body: body} ->
        timestamp = fm["timestamp"] || "unknown"
        type = fm["type"] || "unknown"
        outcome = fm["outcome"] || "unknown"
        summary = fm["summary"] || ""
        lesson = extract_lesson(body)

        """
        - [#{timestamp}] #{type} (#{outcome})
          Summary: #{summary}
          Key lesson: #{lesson}
        """
        |> String.trim()
      end)

    "## Relevant Past Experiences\n\n#{blocks}"
  end

  defp format_procedures([]), do: ""

  defp format_procedures(procedures) do
    blocks =
      Enum.map_join(procedures, "\n\n", fn %{frontmatter: fm, body: body} ->
        summary = fm["summary"] || ""
        confidence = fm["confidence"] || "unknown"
        trigger = extract_when_to_apply(body)

        """
        - #{summary}
          Confidence: #{confidence}
          When to apply: #{trigger}
        """
        |> String.trim()
      end)

    "## Relevant Procedures\n\n#{blocks}"
  end

  defp extract_lesson(body) when is_binary(body) do
    case Regex.run(~r/## Lessons\s*\n+(.*?)(?=\n## |\z)/s, body) do
      [_, lesson] -> lesson |> String.trim() |> String.split("\n", parts: 2) |> hd()
      _ -> "No explicit lesson recorded."
    end
  end

  defp extract_lesson(_), do: "No explicit lesson recorded."

  defp extract_when_to_apply(body) when is_binary(body) do
    case Regex.run(~r/## When to apply\s*\n+(.*?)(?=\n## |\z)/s, body) do
      [_, text] -> text |> String.trim() |> String.split("\n", parts: 2) |> hd()
      _ -> "Use when similar conditions are detected."
    end
  end

  defp extract_when_to_apply(_), do: "Use when similar conditions are detected."
end
