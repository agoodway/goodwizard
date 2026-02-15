defmodule Goodwizard.Actions.Brain.CreateEntity do
  @moduledoc """
  Creates a new entity in the brain knowledge base.
  """

  use Jido.Action,
    name: "create_entity",
    description: "Create a new entity of a given type in the brain knowledge base",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"notes\", \"contacts\")"
      ],
      data: [type: :map, required: true, doc: "Entity data as a map of field names to values"],
      body: [type: :string, default: "", doc: "Optional markdown body content"]
    ]

  require Logger

  alias Goodwizard.Actions.Brain.Helpers

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    workspace = Helpers.workspace(context)
    body = Map.get(params, :body, "")

    Logger.info(fn ->
      "[Brain.CreateEntity] workspace=#{workspace} type=#{params.entity_type} keys=#{inspect(Map.keys(params.data))}"
    end)

    case Goodwizard.Brain.create(workspace, params.entity_type, params.data, body) do
      {:ok, {id, data, body}} ->
        Logger.info("[Brain.CreateEntity] created id=#{id} type=#{params.entity_type}")
        {:ok, %{id: id, data: data, body: body}}

      {:error, reason} ->
        Logger.error(fn ->
          "[Brain.CreateEntity] failed type=#{params.entity_type} reason=#{inspect(reason)}"
        end)

        {:error, Helpers.format_error(reason)}
    end
  end
end
