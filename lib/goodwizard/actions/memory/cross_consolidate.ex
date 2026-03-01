defmodule Goodwizard.Actions.Memory.CrossConsolidate do
  @moduledoc """
  Cross-type consolidation that infers new procedures from episodic patterns.

  Analyzes recent successful episodes to detect recurring patterns and creates
  new procedural memories with `source: "inferred"` and `confidence: "low"`.
  """

  use Jido.Action,
    name: "cross_consolidate",
    description:
      "Analyze recent successful episodes to detect recurring patterns and create inferred procedures",
    schema: [
      episode_limit: [
        type: :integer,
        default: 20,
        doc: "Maximum number of recent successful episodes to analyze"
      ],
      min_episodes: [
        type: :integer,
        default: 5,
        doc: "Minimum successful episodes required before cross-consolidation runs"
      ]
    ]

  require Logger

  alias Goodwizard.Actions.Memory.Helpers
  alias Goodwizard.Memory.Episodic
  alias Goodwizard.Memory.Procedural

  @cross_consolidation_prompt """
  You are a pattern detection assistant. You will receive a set of successful episodic memories
  and a list of existing procedural memories. Your job is to identify recurring patterns across
  the episodes that should become new procedures.

  <existing_procedures>
  <%= existing_procedures %>
  </existing_procedures>

  <recent_episodes>
  <%= episodes %>
  </recent_episodes>

  Rules:
  - Only suggest procedures that do NOT duplicate existing ones
  - Focus on patterns that appear in 2 or more episodes
  - Each procedure should be actionable and specific
  - Use one of these types: workflow, preference, rule, strategy, tool_usage

  Respond with ONLY a JSON array (no markdown fencing). Each element should have:
  - "type": one of "workflow", "preference", "rule", "strategy", "tool_usage"
  - "summary": a concise description (max 200 chars)
  - "tags": array of relevant tags
  - "when_to_apply": when this procedure should be used
  - "steps": step-by-step instructions
  - "notes": any caveats or additional context

  If no patterns are detected, respond with an empty array: []
  """

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    memory_dir = Helpers.memory_dir(context)
    episode_limit = Map.get(params, :episode_limit, 20) |> min(50)
    min_episodes = Map.get(params, :min_episodes, 5)

    with {:ok, episodes} <- load_successful_episodes(memory_dir, episode_limit) do
      continue_run(memory_dir, episodes, min_episodes)
    end
  end

  defp continue_run(memory_dir, episodes, min_episodes) do
    case check_minimum_episodes(episodes, min_episodes) do
      :sufficient -> create_from_patterns(memory_dir, episodes)
      {:insufficient, count} -> {:ok, insufficient_result(count, min_episodes)}
    end
  end

  defp create_from_patterns(memory_dir, episodes) do
    with {:ok, existing_procedures} <- load_existing_procedures(memory_dir),
         {:ok, suggestions} <- detect_patterns(episodes, existing_procedures),
         {:ok, created} <- create_inferred_procedures(memory_dir, suggestions) do
      {:ok,
       %{
         procedures_created: length(created),
         created_summaries: Enum.map(created, & &1["summary"]),
         message: "Cross-consolidation complete: #{length(created)} procedures inferred"
       }}
    end
  end

  defp insufficient_result(count, min_episodes) do
    %{
      procedures_created: 0,
      created_summaries: [],
      message: "Insufficient episodes for cross-consolidation (#{count}/#{min_episodes})"
    }
  end

  defp load_successful_episodes(memory_dir, limit) do
    case Episodic.list(memory_dir, outcome: "success", limit: limit) do
      {:ok, episodes} ->
        episodes_with_bodies =
          Enum.map(episodes, &hydrate_episode(memory_dir, &1))

        {:ok, episodes_with_bodies}

      {:error, reason} ->
        {:error, "Failed to load episodes: #{inspect(reason)}"}
    end
  end

  defp check_minimum_episodes(episodes, min_episodes) do
    if length(episodes) >= min_episodes do
      :sufficient
    else
      {:insufficient, length(episodes)}
    end
  end

  defp load_existing_procedures(memory_dir) do
    case Procedural.list(memory_dir, limit: 200) do
      {:ok, procedures} -> {:ok, procedures}
      {:error, reason} -> {:error, "Failed to load procedures: #{inspect(reason)}"}
    end
  end

  defp detect_patterns(episodes, existing_procedures) do
    episodes_text = format_episodes_for_prompt(episodes)
    procedures_text = format_procedures_for_prompt(existing_procedures)

    prompt =
      @cross_consolidation_prompt
      |> String.replace("<%= existing_procedures %>", Helpers.xml_escape(procedures_text))
      |> String.replace("<%= episodes %>", Helpers.xml_escape(episodes_text))

    case call_llm(prompt) do
      {:ok, suggestions} when is_list(suggestions) -> {:ok, suggestions}
      {:ok, _} -> {:ok, []}
      {:error, reason} -> {:error, "Pattern detection failed: #{inspect(reason)}"}
    end
  end

  defp create_inferred_procedures(memory_dir, suggestions) do
    created =
      Enum.flat_map(suggestions, &create_inferred_from_suggestion(memory_dir, &1))

    {:ok, created}
  end

  defp create_inferred_from_suggestion(memory_dir, suggestion) when is_map(suggestion) do
    frontmatter = %{
      "type" => suggestion_value(suggestion, "type") || "rule",
      "summary" => suggestion_value(suggestion, "summary") || "Inferred procedure",
      "source" => "inferred",
      "confidence" => "low",
      "tags" => normalize_tags(suggestion_value(suggestion, "tags"))
    }

    body = build_procedure_body(suggestion)

    case Procedural.create(memory_dir, frontmatter, body) do
      {:ok, fm} ->
        [fm]

      {:error, reason} ->
        Logger.warning("Failed to create inferred procedure: #{inspect(reason)}")
        []
    end
  end

  defp create_inferred_from_suggestion(_memory_dir, malformed) do
    Logger.warning("Skipping malformed inferred procedure suggestion: #{inspect(malformed)}")
    []
  end

  defp format_episodes_for_prompt(episodes) do
    episodes
    |> Enum.map_join("\n", fn {fm, body} ->
      """
      Episode: #{fm["summary"]}
      Type: #{fm["type"]}
      Outcome: #{fm["outcome"]}
      Tags: #{Enum.join(fm["tags"] || [], ", ")}
      ---
      #{body}
      ===
      """
    end)
  end

  defp format_procedures_for_prompt(procedures) do
    if procedures == [] do
      "(none)"
    else
      procedures
      |> Enum.map_join("\n", fn fm ->
        "- [#{fm["type"]}] #{fm["summary"]} (confidence: #{fm["confidence"]}, tags: #{Enum.join(fm["tags"] || [], ", ")})"
      end)
    end
  end

  defp build_procedure_body(suggestion) do
    when_to_apply =
      suggestion_value(suggestion, "when_to_apply") || "When the pattern is recognized"

    steps = suggestion_value(suggestion, "steps") || "Follow the identified pattern"
    notes = suggestion_value(suggestion, "notes") || "Inferred from episodic patterns"

    """
    ## When to apply

    #{when_to_apply}

    ## Steps

    #{steps}

    ## Notes

    #{notes}
    """
    |> String.trim()
  end

  defp suggestion_value(suggestion, "type"),
    do: Map.get(suggestion, "type") || Map.get(suggestion, :type)

  defp suggestion_value(suggestion, "summary"),
    do: Map.get(suggestion, "summary") || Map.get(suggestion, :summary)

  defp suggestion_value(suggestion, "when_to_apply"),
    do: Map.get(suggestion, "when_to_apply") || Map.get(suggestion, :when_to_apply)

  defp suggestion_value(suggestion, "steps"),
    do: Map.get(suggestion, "steps") || Map.get(suggestion, :steps)

  defp suggestion_value(suggestion, "notes"),
    do: Map.get(suggestion, "notes") || Map.get(suggestion, :notes)

  defp suggestion_value(suggestion, "tags"),
    do: Map.get(suggestion, "tags") || Map.get(suggestion, :tags)

  defp normalize_tags(tags) when is_list(tags) do
    Enum.filter(tags, &is_binary/1)
  end

  defp normalize_tags(_), do: []

  defp hydrate_episode(memory_dir, frontmatter) do
    case Episodic.read(memory_dir, frontmatter["id"]) do
      {:ok, {full_fm, body}} -> {full_fm, body}
      _ -> {frontmatter, ""}
    end
  end

  defp call_llm(prompt) do
    maybe_store_last_prompt(prompt)

    case test_llm_response() do
      nil -> do_call_llm(prompt)
      response -> parse_json_response(response)
    end
  end

  if Mix.env() == :test do
    defp maybe_store_last_prompt(prompt) do
      Process.put({__MODULE__, :last_prompt}, prompt)
    end

    defp test_llm_response do
      Process.get({__MODULE__, :test_llm_response})
    end
  else
    defp maybe_store_last_prompt(_prompt), do: :ok
    defp test_llm_response, do: nil
  end

  defp do_call_llm(prompt) do
    # Call ReqLLM directly — see consolidate.ex for explanation.
    with {:ok, context} <- ReqLLM.Context.normalize(prompt),
         {:ok, response} <-
           ReqLLM.Generation.generate_text(
             "anthropic:claude-haiku-4-5",
             context.messages,
             max_tokens: 2048, temperature: 0.7
           ) do
      text = Jido.AI.Text.extract_text(response)
      parse_json_response(text)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_json_response(content) when is_binary(content) do
    cleaned =
      content
      |> String.trim()
      |> String.replace(~r/^```json\n?/, "")
      |> String.replace(~r/\n?```$/, "")
      |> String.trim()

    case Jason.decode(cleaned) do
      {:ok, result} when is_list(result) -> {:ok, result}
      {:ok, _other} -> {:ok, []}
      {:error, reason} -> {:error, "Failed to parse LLM response: #{inspect(reason)}"}
    end
  end

  defp parse_json_response(content) when is_list(content) do
    text =
      content
      |> Enum.filter(fn block ->
        Map.get(block, :type) == "text" || Map.get(block, "type") == "text"
      end)
      |> Enum.map_join("", fn block -> Map.get(block, :text) || Map.get(block, "text") || "" end)

    parse_json_response(text)
  end
end
