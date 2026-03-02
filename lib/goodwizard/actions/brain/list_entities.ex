defmodule Goodwizard.Actions.Brain.ListEntities do
  @moduledoc """
  Lists all entities of a given type from the knowledge base.
  """

  use Jido.Action,
    name: "list_entities",
    description: "List all entities of a given type from the knowledge base",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"notes\", \"contacts\")"
      ]
    ]

  alias Goodwizard.Actions.Brain.Helpers

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    workspace = Helpers.workspace(context)

    case Goodwizard.Brain.list(workspace, params.entity_type) do
      {:ok, entities} ->
        items =
          Enum.map(entities, fn {data, body} ->
            %{data: Helpers.sanitize_entity_data(data), body: body}
          end)

        {:ok, %{entities: items}}

      {:error, reason} ->
        {:error, Helpers.format_error(reason)}
    end
  end
end
