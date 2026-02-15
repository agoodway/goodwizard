defmodule Goodwizard.Actions.Brain.CreateEntity do
  @moduledoc """
  Creates a new entity in the brain knowledge base.
  """

  use Jido.Action,
    name: "create_entity",
    description:
      "Create a new entity in the brain. Pass entity_type and data with fields matching the schema. " <>
        "Example: entity_type=\"companies\", data={\"name\": \"Acme Corp\"}. Use get_schema first to see required fields.",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"people\", \"companies\", \"notes\")"
      ],
      data: [
        type: :map,
        required: true,
        doc:
          "JSON object with fields matching the entity type schema (e.g. {\"name\": \"Alice\", \"email\": \"alice@example.com\"} for people)"
      ],
      body: [type: :string, default: "", doc: "Optional markdown body content"]
    ]

  alias Goodwizard.Actions.Brain.Helpers

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    workspace = Helpers.workspace(context)
    body = Map.get(params, :body, "")

    case Goodwizard.Brain.create(workspace, params.entity_type, params.data, body) do
      {:ok, {id, data, body}} ->
        {:ok, %{id: id, data: data, body: body}}

      {:error, reason} ->
        {:error, Helpers.format_error(reason)}
    end
  end
end
