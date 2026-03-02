defmodule Goodwizard.Actions.Brain.UpdateEntity do
  @moduledoc """
  Updates an existing entity in the knowledge base.
  """

  use Jido.Action,
    name: "update_entity",
    description:
      "Update an existing entity by type and ID. Pass only the fields to change in data. " <>
        "Example: entity_type=\"people\", id=\"abc123\", data={\"email\": \"new@example.com\"}",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"people\", \"companies\", \"notes\")"
      ],
      id: [type: :string, required: true, doc: "The entity ID"],
      data: [
        type: {:map, :string, :any},
        required: true,
        doc: "JSON object with fields to update (e.g. {\"email\": \"new@example.com\"})"
      ],
      body: [type: :string, doc: "Optional new markdown body content (nil preserves existing)"]
    ]

  alias Goodwizard.Actions.Brain.Helpers

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    workspace = Helpers.workspace(context)
    body = Map.get(params, :body)

    case Goodwizard.Brain.update(workspace, params.entity_type, params.id, params.data, body) do
      {:ok, {data, body}} ->
        {:ok, %{data: Helpers.sanitize_entity_data(data), body: body}}

      {:error, reason} ->
        {:error, Helpers.format_error(reason)}
    end
  end
end
