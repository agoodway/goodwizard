defmodule Goodwizard.Actions.Brain.UpdateEntity do
  @moduledoc """
  Updates an existing entity in the brain knowledge base.
  """

  use Jido.Action,
    name: "update_entity",
    description: "Update an existing entity by type and ID in the brain knowledge base",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"notes\", \"contacts\")"
      ],
      id: [type: :string, required: true, doc: "The entity ID"],
      data: [type: :map, required: true, doc: "Fields to update as a map"],
      body: [type: :string, doc: "Optional new markdown body content (nil preserves existing)"]
    ]

  require Logger

  alias Goodwizard.Actions.Brain.Helpers

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    workspace = get_in(context, [:state, :workspace]) || "."
    body = Map.get(params, :body)

    Logger.info(
      "[Brain.UpdateEntity] workspace=#{workspace} type=#{params.entity_type} id=#{params.id}"
    )

    case Goodwizard.Brain.update(workspace, params.entity_type, params.id, params.data, body) do
      {:ok, {data, body}} ->
        Logger.info("[Brain.UpdateEntity] updated id=#{params.id} type=#{params.entity_type}")
        {:ok, %{data: data, body: body}}

      {:error, reason} ->
        Logger.error(fn ->
          "[Brain.UpdateEntity] failed type=#{params.entity_type} id=#{params.id} reason=#{inspect(reason)}"
        end)

        {:error, Helpers.format_error(reason)}
    end
  end
end
