defmodule Goodwizard.Actions.Memory.Episodic.RecordEpisode do
  @moduledoc """
  Records a notable experience as an episodic memory entry.
  """

  use Jido.Action,
    name: "record_episode",
    description:
      "Record a notable experience (task completion, problem solved, error encountered, decision made, or interaction) as an episodic memory entry",
    schema: [
      type: [
        type:
          {:in,
           ~w(task_completion problem_solved error_encountered decision_made interaction monthly_summary)},
        required: true,
        doc:
          "Type of episode: task_completion, problem_solved, error_encountered, decision_made, or interaction"
      ],
      summary: [
        type: :string,
        required: true,
        doc: "Brief summary of the episode (max 200 characters)"
      ],
      outcome: [
        type: {:in, ~w(success failure partial abandoned)},
        required: true,
        doc: "Outcome of the episode: success, failure, partial, or abandoned"
      ],
      observation: [
        type: :string,
        required: true,
        doc: "What was the situation? What did you observe?"
      ],
      approach: [
        type: :string,
        required: true,
        doc: "What strategy or approach was taken?"
      ],
      result: [
        type: :string,
        required: true,
        doc: "What was the result of the approach?"
      ],
      lessons: [
        type: :string,
        required: false,
        doc: "What lessons were learned? What would you do differently?"
      ],
      tags: [
        type: {:list, :string},
        required: false,
        doc: "Tags for categorizing this episode"
      ],
      entities_involved: [
        type: {:list, :string},
        required: false,
        doc: "Names or IDs of entities involved in this episode"
      ]
    ]

  alias Goodwizard.Actions.Memory.Helpers
  alias Goodwizard.Memory.Episodic

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    memory_dir = Helpers.memory_dir(context)

    frontmatter = %{
      "type" => params.type,
      "summary" => params.summary,
      "outcome" => params.outcome,
      "tags" => Map.get(params, :tags, []),
      "entities_involved" => Map.get(params, :entities_involved, [])
    }

    body = build_body(params)

    case Episodic.create(memory_dir, frontmatter, body) do
      {:ok, episode} ->
        {:ok, %{episode: episode, message: "Episode recorded: #{episode["summary"]}"}}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp build_body(params) do
    sections = [
      {"Observation", params.observation},
      {"Approach", params.approach},
      {"Result", params.result},
      {"Lessons", Map.get(params, :lessons, "")}
    ]

    sections
    |> Enum.reject(fn {_title, content} -> content == "" or is_nil(content) end)
    |> Enum.map_join("\n\n", fn {title, content} -> "## #{title}\n\n#{content}" end)
  end

  defp format_error({:missing_required, field}), do: "Missing required field: #{field}"
  defp format_error({:invalid_type, type}), do: "Invalid episode type: #{type}"
  defp format_error({:invalid_outcome, outcome}), do: "Invalid outcome: #{outcome}"
  defp format_error({:list_too_long, field}), do: "Too many items in #{field}"
  defp format_error({:element_too_long, field}), do: "Element too long in #{field}"
  defp format_error({:invalid_list_element, field}), do: "Invalid element in #{field}"
  defp format_error({:invalid_list_field, field}), do: "Invalid list field: #{field}"
  defp format_error({:fs_error, reason}), do: "File system error: #{:file.format_error(reason)}"
  defp format_error(reason), do: "Failed to record episode: #{inspect(reason)}"
end
