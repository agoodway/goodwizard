defmodule Goodwizard.Actions.Brain.ListEntities do
  @moduledoc """
  Lists all entities of a given type from the brain knowledge base.
  """

  use Jido.Action,
    name: "list_entities",
    description: "List all entities of a given type from the brain knowledge base",
    schema: [
      entity_type: [type: :string, required: true, doc: "The entity type (e.g. \"notes\", \"contacts\")"]
    ]

  @impl true
  def run(params, context) do
    workspace = get_in(context, [:state, :workspace]) || "."

    case Goodwizard.Brain.list(workspace, params.entity_type) do
      {:ok, entities} ->
        items = Enum.map(entities, fn {data, body} -> %{data: data, body: body} end)
        {:ok, %{entities: items, count: length(items)}}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
