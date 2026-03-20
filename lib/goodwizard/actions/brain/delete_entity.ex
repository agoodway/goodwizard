defmodule Goodwizard.Actions.Brain.DeleteEntity do
  @moduledoc """
  Deletes an entity from the knowledge base.
  """

  use Jido.Action,
    name: "delete_entity",
    description: "Delete an entity by type and ID from the knowledge base",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"notes\", \"contacts\")"
      ],
      id: [type: :string, required: true, doc: "The entity ID"]
    ]

  alias Goodwizard.Actions.Brain.Helpers
  alias Goodwizard.Brain.Seeds

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    workspace = Helpers.workspace(context)

    if protected_seeded_schema_delete?(params.entity_type, params.id) do
      {:error, Helpers.format_error({:protected_entity_type, params.entity_type})}
    else
      case Goodwizard.Brain.delete(workspace, params.entity_type, params.id) do
        :ok ->
          {:ok, %{message: "Entity #{params.id} deleted from #{params.entity_type}"}}

        {:error, reason} ->
          {:error, Helpers.format_error(reason)}
      end
    end
  end

  defp protected_seeded_schema_delete?(entity_type, id) do
    Seeds.seeded_type?(entity_type) and schema_delete_target?(entity_type, id)
  end

  defp schema_delete_target?(entity_type, id) do
    id in [entity_type, "schema", "__schema__", "#{entity_type}.json"]
  end
end
