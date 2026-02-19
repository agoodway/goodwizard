defmodule Goodwizard.Actions.Memory.Procedural.ListProcedures do
  @moduledoc """
  Lists procedural memory entries with optional filters.
  """

  use Jido.Action,
    name: "list_procedures",
    description: "List learned procedures, optionally filtered by type or minimum confidence",
    schema: [
      limit: [
        type: :integer,
        required: false,
        default: 20,
        doc: "Maximum number of procedures to return (default 20)"
      ],
      type: [
        type: :string,
        required: false,
        doc: "Filter by procedure type"
      ],
      confidence: [
        type: :string,
        required: false,
        doc: "Minimum confidence level"
      ]
    ]

  alias Goodwizard.Actions.Memory.Helpers
  alias Goodwizard.Memory.Procedural

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    memory_dir = Helpers.memory_dir(context)
    opts = build_opts(params)

    case Procedural.list(memory_dir, opts) do
      {:ok, procedures} ->
        {:ok, %{procedures: procedures, count: length(procedures)}}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp build_opts(params) do
    []
    |> maybe_add(:limit, Map.get(params, :limit))
    |> maybe_add(:type, Map.get(params, :type))
    |> maybe_add(:confidence, Map.get(params, :confidence))
  end

  defp maybe_add(opts, _key, nil), do: opts
  defp maybe_add(opts, key, value), do: Keyword.put(opts, key, value)

  defp format_error(reason), do: "Failed to list procedures: #{inspect(reason)}"
end
