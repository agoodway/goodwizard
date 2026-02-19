defmodule Goodwizard.Actions.Memory.Procedural.UpdateProcedure do
  @moduledoc """
  Updates an existing procedural memory entry.
  """

  use Jido.Action,
    name: "update_procedure",
    description:
      "Update an existing procedure's metadata and optionally rebuild when-to-apply/steps/notes",
    schema: [
      id: [
        type: :string,
        required: true,
        doc: "The ID of the procedure to update"
      ],
      summary: [
        type: :string,
        required: false,
        doc: "Updated summary (max 200 characters)"
      ],
      tags: [
        type: {:list, :string},
        required: false,
        doc: "Updated tags"
      ],
      confidence: [
        type: {:in, ~w(high medium low)},
        required: false,
        doc: "Updated confidence level"
      ],
      when_to_apply: [
        type: :string,
        required: false,
        doc: "Updated when-to-apply section"
      ],
      steps: [
        type: :string,
        required: false,
        doc: "Updated steps section"
      ],
      notes: [
        type: :string,
        required: false,
        doc: "Updated notes section"
      ]
    ]

  alias Goodwizard.Actions.Memory.Helpers
  alias Goodwizard.Memory.Procedural

  @max_summary_length 200

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    memory_dir = Helpers.memory_dir(context)
    frontmatter_updates = build_frontmatter_updates(params)
    maybe_body = build_optional_body(params)

    case Procedural.update(memory_dir, params.id, frontmatter_updates, maybe_body) do
      {:ok, procedure} ->
        {:ok, %{procedure: procedure, message: "Procedure updated: #{procedure["summary"]}"}}

      {:error, :not_found} ->
        {:error, "Procedure not found: #{params.id}"}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp build_frontmatter_updates(params) do
    %{}
    |> maybe_put("summary", maybe_truncate(Map.get(params, :summary)))
    |> maybe_put("tags", Map.get(params, :tags))
    |> maybe_put("confidence", Map.get(params, :confidence))
  end

  defp maybe_truncate(nil), do: nil

  defp maybe_truncate(summary) when is_binary(summary) do
    if String.length(summary) > @max_summary_length do
      String.slice(summary, 0, @max_summary_length)
    else
      summary
    end
  end

  defp build_optional_body(params) do
    if Enum.any?([:when_to_apply, :steps, :notes], &Map.has_key?(params, &1)) do
      build_body(params)
    else
      nil
    end
  end

  defp build_body(params) do
    when_to_apply = Map.get(params, :when_to_apply, "")
    steps = Map.get(params, :steps, "")
    notes = Map.get(params, :notes, "")

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

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp format_error(:invalid_id), do: "Invalid procedure ID format"

  defp format_error({:invalid_confidence, confidence}),
    do: "Invalid confidence level: #{confidence}"

  defp format_error({:fs_error, reason}), do: "File system error: #{:file.format_error(reason)}"
  defp format_error(reason), do: "Failed to update procedure: #{inspect(reason)}"
end
