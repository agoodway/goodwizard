defmodule Goodwizard.Actions.Brain.ReadEntity do
  @moduledoc """
  Reads an entity from the brain knowledge base by type and ID.
  """

  use Jido.Action,
    name: "read_entity",
    description: "Read an entity by type and ID from the brain knowledge base",
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
    workspace = Helpers.workspace(context)

    Logger.info(
      "[Brain.ReadEntity] workspace=#{workspace} type=#{params.entity_type} id=#{params.id}"
    )

    case Goodwizard.Brain.read(workspace, params.entity_type, params.id) do
      {:ok, {data, body}} ->
        Logger.info("[Brain.ReadEntity] read id=#{params.id} type=#{params.entity_type}")
        {:ok, %{data: data, body: body}}

      {:error, reason} ->
        Logger.error(fn ->
          "[Brain.ReadEntity] failed type=#{params.entity_type} id=#{params.id} reason=#{inspect(reason)}"
        end)

        {:error, Helpers.format_error(reason)}
    end
  end
end
