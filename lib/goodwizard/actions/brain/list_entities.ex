defmodule Goodwizard.Actions.Brain.ListEntities do
  @moduledoc """
  Lists all entities of a given type from the brain knowledge base.
  """

  use Jido.Action,
    name: "list_entities",
    description: "List all entities of a given type from the brain knowledge base",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"notes\", \"contacts\")"
      ]
    ]

  require Logger

  alias Goodwizard.Actions.Brain.Helpers

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    workspace = Helpers.workspace(context)

    Logger.info("[Brain.ListEntities] workspace=#{workspace} type=#{params.entity_type}")

    case Goodwizard.Brain.list(workspace, params.entity_type) do
      {:ok, entities} ->
        items = Enum.map(entities, fn {data, body} -> %{data: data, body: body} end)

        Logger.info(
          "[Brain.ListEntities] found #{length(items)} entities type=#{params.entity_type}"
        )

        {:ok, %{entities: items}}

      {:error, reason} ->
        Logger.error(fn ->
          "[Brain.ListEntities] failed type=#{params.entity_type} reason=#{inspect(reason)}"
        end)

        {:error, Helpers.format_error(reason)}
    end
  end
end
