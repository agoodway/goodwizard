defmodule Goodwizard.Actions.Memory.Procedural.RecallProcedures do
  @moduledoc """
  Recalls relevant procedures for a described situation.
  """

  use Jido.Action,
    name: "recall_procedures",
    description:
      "Recall relevant procedures for the current situation, ranked by relevance and confidence",
    schema: [
      situation: [
        type: :string,
        required: true,
        doc: "Description of the current situation"
      ],
      tags: [
        type: {:list, :string},
        required: false,
        doc: "Optional tags to bias recall"
      ],
      type: [
        type: :string,
        required: false,
        doc: "Optional filter by procedure type"
      ],
      limit: [
        type: :integer,
        required: false,
        default: 5,
        doc: "Maximum number of procedures to return (default 5)"
      ]
    ]

  alias Goodwizard.Actions.Memory.Helpers
  alias Goodwizard.Memory.Procedural

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    memory_dir = Helpers.memory_dir(context)
    opts = build_opts(params)
    requested_limit = Map.get(params, :limit, 5)

    case Procedural.recall(memory_dir, params.situation, opts) do
      {:ok, procedures} ->
        filtered = maybe_filter_by_tags(procedures, Map.get(params, :tags, []))
        limited = Enum.take(filtered, requested_limit)
        {:ok, %{procedures: limited, count: length(limited)}}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp build_opts(params) do
    []
    |> maybe_add(:tags, Map.get(params, :tags))
    |> maybe_add(:type, Map.get(params, :type))
    |> maybe_add(:limit, Map.get(params, :limit))
  end

  defp maybe_add(opts, _key, nil), do: opts
  defp maybe_add(opts, key, value), do: Keyword.put(opts, key, value)

  defp maybe_filter_by_tags(procedures, []), do: procedures

  defp maybe_filter_by_tags(procedures, tags) do
    Enum.filter(procedures, fn procedure ->
      procedure_tags = Map.get(procedure, "tags", [])
      Enum.all?(tags, &(&1 in procedure_tags))
    end)
  end

  defp format_error(reason), do: "Failed to recall procedures: #{inspect(reason)}"
end
