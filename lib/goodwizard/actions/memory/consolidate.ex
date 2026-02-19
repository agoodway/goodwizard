defmodule Goodwizard.Actions.Memory.Consolidate do
  @moduledoc """
  LLM-driven memory consolidation.

  Takes old session messages (beyond the memory window), formats them,
  calls the LLM for a consolidation summary, then updates HISTORY.md
  and MEMORY.md accordingly, and trims the session to the most recent
  N messages.
  """

  use Jido.Action,
    name: "consolidate",
    description: "Consolidate old conversation messages into long-term memory and history",
    schema: [
      memory_dir: [type: :string, required: true, doc: "Path to the memory directory"],
      messages: [type: {:list, :map}, required: true, doc: "All session messages"],
      memory_window: [type: :integer, default: 50, doc: "Number of recent messages to keep"],
      current_memory: [type: :string, default: "", doc: "Current MEMORY.md content"]
    ]

  require Logger

  alias Goodwizard.Memory.Episodic
  alias Goodwizard.Memory.Paths
  alias Goodwizard.Memory.Procedural

  @consolidation_prompt """
  You are a memory consolidation assistant. You will receive a conversation transcript,
  the current semantic memory profile, and existing procedure summaries.

  Extract information into three memory types:

  1. episodes: notable experiences/outcomes (episodic memory)
  2. memory_profile_update: updated semantic profile text for MEMORY.md
  3. procedural_insights: reusable patterns/how-to guidance (procedural memory)

  <current_memory>
  <%= current_memory %>
  </current_memory>

  <existing_procedures>
  <%= existing_procedures %>
  </existing_procedures>

  <conversation>
  <%= formatted_messages %>
  </conversation>

  For procedures:
  - If an insight refines an existing procedure, include "updates_existing": "<procedure_id>"
  - If it is net new, omit updates_existing

  Respond with ONLY a JSON object (no markdown fencing) with keys:
  - "episodes": array of episode objects with required keys:
    type, summary, outcome, observation, approach, result
    optional keys: tags (array), entities_involved (array), lessons (string)
  - "memory_profile_update": full updated MEMORY.md content as a string
  - "procedural_insights": array of procedure objects with required keys:
    type, summary, when_to_apply, steps
    optional keys: tags (array), notes (string), updates_existing (string)

  If nothing is found for episodes/procedures, return empty arrays for those keys.
  """

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, _context) do
    messages = params.messages
    memory_window = Map.get(params, :memory_window, 50)
    current_memory = Map.get(params, :current_memory, "")
    memory_dir = params.memory_dir

    with {:ok, _} <- Paths.validate_memory_dir(memory_dir) do
      total = length(messages)

      if total <= memory_window do
        {:ok, %{consolidated: false, message: "No consolidation needed", messages: messages}}
      else
        do_consolidate(messages, total, memory_window, current_memory, memory_dir)
      end
    else
      {:error, :path_traversal} -> {:error, "memory_dir path traversal is not allowed"}
      {:error, reason} -> {:error, "Invalid memory_dir: #{inspect(reason)}"}
    end
  end

  defp do_consolidate(messages, total, memory_window, current_memory, memory_dir) do
    old_messages = Enum.take(messages, total - memory_window)
    recent_messages = Enum.take(messages, -memory_window)

    formatted = format_messages(old_messages)
    existing_procedures = load_existing_procedures(memory_dir)
    prompt = build_prompt(current_memory, formatted, existing_procedures)

    case call_llm(prompt) do
      {:ok,
       %{
         "episodes" => episodes,
         "memory_profile_update" => memory_update,
         "procedural_insights" => procedural_insights
       }} ->
        with :ok <- write_memory(memory_dir, memory_update),
             {:ok, episode_result} <- write_episodes(memory_dir, episodes),
             {:ok, procedure_result} <- write_procedures(memory_dir, procedural_insights),
             :ok <- write_audit_log(memory_dir, episode_result, procedure_result, memory_update) do
          {:ok,
           %{
             consolidated: true,
             message: "Consolidated #{length(old_messages)} messages",
             messages: recent_messages,
             memory_content: memory_update,
             episodes_created: episode_result.created,
             episodes_failed: episode_result.failed,
             procedures_created: procedure_result.created,
             procedures_updated: procedure_result.updated,
             procedures_failed: procedure_result.failed
           }}
        else
          {:error, reason} ->
            Logger.warning("Consolidation file write failed: #{inspect(reason)}")

            {:ok,
             %{
               consolidated: false,
               message: "Consolidation file write failed: #{inspect(reason)}",
               messages: messages
             }}
        end

      {:error, reason} ->
        Logger.warning("Consolidation LLM call failed: #{inspect(reason)}")

        {:ok,
         %{
           consolidated: false,
           message: "Consolidation failed: #{inspect(reason)}",
           messages: messages
         }}
    end
  end

  defp build_prompt(current_memory, formatted_messages, existing_procedures) do
    escaped_memory = xml_escape(current_memory)
    escaped_messages = xml_escape(formatted_messages)
    escaped_procedures = xml_escape(format_existing_procedures(existing_procedures))

    @consolidation_prompt
    |> String.replace("<%= current_memory %>", escaped_memory)
    |> String.replace("<%= existing_procedures %>", escaped_procedures)
    |> String.replace("<%= formatted_messages %>", escaped_messages)
  end

  defp xml_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp format_messages(messages) do
    Enum.map_join(messages, "\n", fn msg ->
      timestamp = Map.get(msg, :timestamp, "unknown")
      role = Map.get(msg, :role, "unknown")
      content = Map.get(msg, :content, "")
      "[#{timestamp}] #{role}: #{content}"
    end)
  end

  defp load_existing_procedures(memory_dir) do
    case Procedural.list(memory_dir, limit: 200) do
      {:ok, procedures} ->
        procedures

      {:error, reason} ->
        Logger.warning("Failed to load procedures for consolidation prompt: #{inspect(reason)}")
        []
    end
  end

  defp format_existing_procedures([]), do: "(none)"

  defp format_existing_procedures(procedures) do
    procedures
    |> Enum.map_join("\n", fn procedure ->
      id = Map.get(procedure, "id", "unknown")
      type = Map.get(procedure, "type", "unknown")
      summary = Map.get(procedure, "summary", "")
      tags = Map.get(procedure, "tags", []) |> Enum.join(", ")
      "- id: #{id} | type: #{type} | summary: #{summary} | tags: [#{tags}]"
    end)
  end

  defp call_llm(prompt) do
    Process.put({__MODULE__, :last_prompt}, prompt)

    case Process.get({__MODULE__, :test_llm_response}) do
      nil ->
        do_call_llm(prompt)

      test_response ->
        parse_json_response(test_response)
    end
  end

  defp do_call_llm(prompt) do
    case Jido.Exec.run(Jido.AI.Actions.LLM.Chat, %{
           prompt: prompt,
           model: "anthropic:claude-haiku-4-5",
           max_tokens: 2048
         }) do
      {:ok, %{text: text}} ->
        parse_json_response(text)

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
      {:ok, result} when is_map(result) ->
        validate_response(result)

      {:ok, _other} ->
        {:error, "LLM response must be a JSON object"}

      {:error, reason} ->
        {:error, "Failed to parse LLM response as JSON: #{inspect(reason)}"}
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

  defp parse_json_response(content) when is_map(content) do
    validate_response(content)
  end

  defp validate_response(result) do
    with {:ok, memory_update} <- validate_memory_profile_update(result),
         {:ok, episodes} <- validate_episodes(result),
         {:ok, procedural_insights} <- validate_procedural_insights(result) do
      {:ok,
       %{
         "episodes" => episodes,
         "memory_profile_update" => memory_update,
         "procedural_insights" => procedural_insights
       }}
    end
  end

  defp validate_memory_profile_update(%{"memory_profile_update" => value}) when is_binary(value),
    do: {:ok, value}

  defp validate_memory_profile_update(_),
    do: {:error, "LLM response missing required string field: memory_profile_update"}

  defp validate_episodes(result) do
    episodes = Map.get(result, "episodes", [])

    if is_list(episodes) do
      validate_episode_items(episodes)
    else
      {:error, "LLM response field episodes must be an array"}
    end
  end

  defp validate_episode_items(episodes) do
    required = ~w(type summary outcome observation approach result)

    case Enum.find(episodes, fn item -> not valid_object_with_fields?(item, required) end) do
      nil -> {:ok, episodes}
      _ -> {:error, "Episode items must include: #{Enum.join(required, ", ")}"}
    end
  end

  defp validate_procedural_insights(result) do
    insights = Map.get(result, "procedural_insights", [])

    if is_list(insights) do
      validate_procedural_items(insights)
    else
      {:error, "LLM response field procedural_insights must be an array"}
    end
  end

  defp validate_procedural_items(insights) do
    required = ~w(type summary when_to_apply steps)

    case Enum.find(insights, fn item -> not valid_object_with_fields?(item, required) end) do
      nil -> {:ok, insights}
      _ -> {:error, "Procedural insight items must include: #{Enum.join(required, ", ")}"}
    end
  end

  defp valid_object_with_fields?(item, required_fields) when is_map(item) do
    Enum.all?(required_fields, fn field ->
      value = Map.get(item, field)
      is_binary(value) and String.trim(value) != ""
    end)
  end

  defp valid_object_with_fields?(_item, _required_fields), do: false

  defp write_audit_log(memory_dir, episode_result, procedure_result, memory_update) do
    path = Paths.history_path(memory_dir)
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    lines = [
      "## #{timestamp} -- Consolidation",
      "Extracted #{episode_result.created} episodes (#{episode_result.failed} failed), " <>
        "created #{procedure_result.created} procedures, updated #{procedure_result.updated} procedures " <>
        "(#{procedure_result.failed} failed).",
      "MEMORY.md updated: #{if(memory_update == "", do: "no", else: "yes")}",
      "Episode summaries: #{summaries_or_none(episode_result.summaries)}",
      "Procedural summaries: #{summaries_or_none(procedure_result.summaries)}",
      ""
    ]

    entry = Enum.join(lines, "\n") <> "\n"

    with :ok <- Paths.ensure_dir(memory_dir),
         :ok <- File.write(path, entry, [:append]) do
      File.chmod(path, 0o600)
      :ok
    end
  end

  defp summaries_or_none([]), do: "none"
  defp summaries_or_none(summaries), do: Enum.join(summaries, "; ")

  defp write_episodes(memory_dir, episodes) do
    result =
      Enum.reduce(episodes, %{created: 0, failed: 0, summaries: []}, fn episode, acc ->
        frontmatter = %{
          "type" => episode["type"],
          "summary" => episode["summary"],
          "outcome" => episode["outcome"],
          "tags" => Map.get(episode, "tags", []),
          "entities_involved" => Map.get(episode, "entities_involved", [])
        }

        body = build_episode_body(episode)

        case Episodic.create(memory_dir, frontmatter, body) do
          {:ok, _created} ->
            %{acc | created: acc.created + 1, summaries: acc.summaries ++ [episode["summary"]]}

          {:error, reason} ->
            Logger.warning(
              "Consolidation failed to write episode '#{episode["summary"]}': #{inspect(reason)}"
            )

            %{acc | failed: acc.failed + 1}
        end
      end)

    {:ok, result}
  end

  defp build_episode_body(episode) do
    lesson = Map.get(episode, "lessons", "")

    sections = [
      {"Observation", episode["observation"]},
      {"Approach", episode["approach"]},
      {"Result", episode["result"]},
      {"Lessons", lesson},
      {
        "Source",
        "Extracted during consolidation from prior conversation context (not recorded in real-time)."
      }
    ]

    sections
    |> Enum.reject(fn {_title, content} -> is_nil(content) or String.trim(content) == "" end)
    |> Enum.map_join("\n\n", fn {title, content} -> "## #{title}\n\n#{content}" end)
  end

  defp write_procedures(memory_dir, procedural_insights) do
    result =
      Enum.reduce(
        procedural_insights,
        %{created: 0, updated: 0, failed: 0, summaries: []},
        fn insight, acc ->
          case write_single_procedure(memory_dir, insight) do
            {:ok, :created} ->
              %{acc | created: acc.created + 1, summaries: acc.summaries ++ [insight["summary"]]}

            {:ok, :updated} ->
              %{acc | updated: acc.updated + 1, summaries: acc.summaries ++ [insight["summary"]]}

            {:error, reason} ->
              Logger.warning(
                "Consolidation failed to write procedure '#{insight["summary"]}': #{inspect(reason)}"
              )

              %{acc | failed: acc.failed + 1}
          end
        end
      )

    {:ok, result}
  end

  defp write_single_procedure(memory_dir, %{"updates_existing" => id} = insight)
       when is_binary(id) and id != "" do
    updates = %{
      "type" => insight["type"],
      "summary" => insight["summary"],
      "tags" => Map.get(insight, "tags", [])
    }

    body = build_procedure_body(insight)

    case Procedural.update(memory_dir, id, updates, body) do
      {:ok, _procedure} -> {:ok, :updated}
      {:error, reason} -> {:error, reason}
    end
  end

  defp write_single_procedure(memory_dir, insight) do
    frontmatter = %{
      "type" => insight["type"],
      "summary" => insight["summary"],
      "source" => "learned",
      "confidence" => "medium",
      "tags" => Map.get(insight, "tags", [])
    }

    body = build_procedure_body(insight)

    case Procedural.create(memory_dir, frontmatter, body) do
      {:ok, _procedure} -> {:ok, :created}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_procedure_body(insight) do
    notes = Map.get(insight, "notes", "")

    [
      {"When to apply", insight["when_to_apply"]},
      {"Steps", insight["steps"]},
      {"Notes", notes}
    ]
    |> Enum.reject(fn {_title, content} -> is_nil(content) or String.trim(content) == "" end)
    |> Enum.map_join("\n\n", fn {title, content} -> "## #{title}\n\n#{content}" end)
  end

  defp write_memory(memory_dir, content) do
    path = Paths.memory_path(memory_dir)

    with :ok <- Paths.ensure_dir(memory_dir),
         :ok <- File.write(path, content) do
      File.chmod(path, 0o600)
      :ok
    end
  end
end
