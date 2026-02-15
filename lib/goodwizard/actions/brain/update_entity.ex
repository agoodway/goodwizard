defmodule Goodwizard.Actions.Brain.UpdateEntity do
  @moduledoc """
  Updates an existing entity in the brain knowledge base.
  """

  use Jido.Action,
    name: "update_entity",
    description: "Update an existing entity by type and ID in the brain knowledge base",
    schema: [
      entity_type: [type: :string, required: true, doc: "The entity type (e.g. \"notes\", \"contacts\")"],
      id: [type: :string, required: true, doc: "The entity ID"],
      data: [type: :map, required: true, doc: "Fields to update as a map"],
      body: [type: :string, doc: "Optional new markdown body content (nil preserves existing)"]
    ]

  @impl true
  def run(params, context) do
    workspace = get_in(context, [:state, :workspace]) || "."
    body = Map.get(params, :body)

    case Goodwizard.Brain.update(workspace, params.entity_type, params.id, params.data, body) do
      {:ok, {data, body}} ->
        {:ok, %{data: data, body: body}}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
