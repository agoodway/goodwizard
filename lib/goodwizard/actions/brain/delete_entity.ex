defmodule Goodwizard.Actions.Brain.DeleteEntity do
  @moduledoc """
  Deletes an entity from the brain knowledge base.
  """

  use Jido.Action,
    name: "delete_entity",
    description: "Delete an entity by type and ID from the brain knowledge base",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"notes\", \"contacts\")"
      ],
      id: [type: :string, required: true, doc: "The entity ID"]
    ]

  require Logger

  alias Goodwizard.Actions.Brain.Helpers

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    workspace = get_in(context, [:state, :workspace]) || "."

    Logger.info(
      "[Brain.DeleteEntity] workspace=#{workspace} type=#{params.entity_type} id=#{params.id}"
    )

    case Goodwizard.Brain.delete(workspace, params.entity_type, params.id) do
      :ok ->
        Logger.info("[Brain.DeleteEntity] deleted id=#{params.id} type=#{params.entity_type}")
        {:ok, %{message: "Entity #{params.id} deleted from #{params.entity_type}"}}

      {:error, reason} ->
        Logger.error(fn ->
          "[Brain.DeleteEntity] failed type=#{params.entity_type} id=#{params.id} reason=#{inspect(reason)}"
        end)

        {:error, Helpers.format_error(reason)}
    end
  end
end
