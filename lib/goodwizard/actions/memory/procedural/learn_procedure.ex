defmodule Goodwizard.Actions.Memory.Procedural.LearnProcedure do
  @moduledoc """
  Records a learned procedure as procedural memory.
  """

  use Jido.Action,
    name: "learn_procedure",
    description:
      "Learn a new reusable procedure (workflow, preference, rule, strategy, or tool usage) for future recall",
    schema: [
      type: [
        type: {:in, ~w(workflow preference rule strategy tool_usage)},
        required: true,
        doc: "Type of procedure: workflow, preference, rule, strategy, or tool_usage"
      ],
      summary: [
        type: :string,
        required: true,
        doc: "Brief summary of the procedure (max 200 characters)"
      ],
      tags: [
        type: {:list, :string},
        required: false,
        doc: "Tags for categorizing this procedure"
      ],
      confidence: [
        type: {:in, ~w(high medium low)},
        required: false,
        default: "medium",
        doc: "Confidence level: high, medium, or low"
      ],
      source: [
        type: {:in, ~w(learned taught inferred)},
        required: true,
        doc: "Source of this procedure: learned, taught, or inferred"
      ],
      when_to_apply: [
        type: :string,
        required: true,
        doc: "When this procedure should be applied"
      ],
      steps: [
        type: :string,
        required: true,
        doc: "Step-by-step instructions"
      ],
      notes: [
        type: :string,
        required: false,
        doc: "Optional caveats or additional context"
      ]
    ]

  alias Goodwizard.Actions.Memory.Helpers
  alias Goodwizard.Memory.Procedural

  @max_summary_length 200

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    memory_dir = Helpers.memory_dir(context)

    frontmatter = %{
      "type" => params.type,
      "summary" => truncate_summary(params.summary),
      "source" => params.source,
      "confidence" => Map.get(params, :confidence, "medium"),
      "tags" => Map.get(params, :tags, [])
    }

    body = build_body(params)

    case Procedural.create(memory_dir, frontmatter, body) do
      {:ok, procedure} ->
        {:ok, %{procedure: procedure, message: "Procedure learned: #{procedure["summary"]}"}}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp truncate_summary(summary) when is_binary(summary) do
    if String.length(summary) > @max_summary_length do
      String.slice(summary, 0, @max_summary_length)
    else
      summary
    end
  end

  defp build_body(params) do
    sections = [
      {"When to apply", params.when_to_apply},
      {"Steps", params.steps},
      {"Notes", Map.get(params, :notes, "")}
    ]

    sections
    |> Enum.reject(fn {_title, content} -> content == "" or is_nil(content) end)
    |> Enum.map_join("\n\n", fn {title, content} -> "## #{title}\n\n#{content}" end)
  end

  defp format_error({:missing_required, field}), do: "Missing required field: #{field}"
  defp format_error({:invalid_type, type}), do: "Invalid procedure type: #{type}"
  defp format_error({:invalid_source, source}), do: "Invalid procedure source: #{source}"

  defp format_error({:invalid_confidence, confidence}),
    do: "Invalid confidence level: #{confidence}"

  defp format_error({:fs_error, reason}), do: "File system error: #{:file.format_error(reason)}"
  defp format_error(reason), do: "Failed to learn procedure: #{inspect(reason)}"
end
