defmodule Goodwizard.Actions.Brain.CreateEntity do
  @moduledoc """
  Creates a new entity in the brain knowledge base.
  """

  use Jido.Action,
    name: "create_entity",
    description: "Create a new entity of a given type in the brain knowledge base",
    schema: [
      entity_type: [type: :string, required: true, doc: "The entity type (e.g. \"notes\", \"contacts\")"],
      data: [type: :map, required: true, doc: "Entity data as a map of field names to values"],
      body: [type: :string, default: "", doc: "Optional markdown body content"]
    ]

  alias Goodwizard.Actions.Brain.Helpers

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    workspace = get_in(context, [:state, :workspace]) || "."
    body = Map.get(params, :body, "")

    case Goodwizard.Brain.create(workspace, params.entity_type, params.data, body) do
      {:ok, {id, data, body}} ->
        {:ok, %{id: id, data: data, body: body}}

      {:error, reason} ->
        {:error, Helpers.format_error(reason)}
    end
  end
end
