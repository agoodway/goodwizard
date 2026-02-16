defmodule Goodwizard.Actions.Brain.CreateEntity do
  @moduledoc """
  Creates a new entity in the brain knowledge base.
  """

  use Jido.Action,
    name: "create_entity",
    description:
      "Generic fallback for creating brain entities. Prefer typed tools like create_note, create_person, " <>
        "create_company, etc. when available — they have proper field-level parameters. " <>
        "Only use this for entity types that lack a dedicated tool.",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"people\", \"companies\", \"notes\")"
      ],
      data: [
        type: {:map, :string, :any},
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

    data = Map.drop(params.data, ["id", :id])

    case Goodwizard.Brain.create(workspace, params.entity_type, data, body) do
      {:ok, {id, data, body}} ->
        {:ok, %{id: id, data: data, body: body}}

      {:error, reason} ->
        {:error, Helpers.format_error(reason)}
    end
  end
end
