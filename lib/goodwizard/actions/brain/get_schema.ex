defmodule Goodwizard.Actions.Brain.GetSchema do
  @moduledoc """
  Retrieves the JSON Schema for a given entity type.
  """

  use Jido.Action,
    name: "get_schema",
    description: "Get the JSON Schema definition for an entity type",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"notes\", \"contacts\")"
      ]
    ]

  require Logger

  alias Goodwizard.Actions.Brain.Helpers
  alias Goodwizard.Brain.Paths

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    workspace = Helpers.workspace(context)

    Logger.info("[Brain.GetSchema] workspace=#{workspace} type=#{params.entity_type}")

    with {:ok, path} <- Paths.schema_path(workspace, params.entity_type),
         {:ok, content} <- File.read(path),
         {:ok, schema_map} <- Jason.decode(content) do
      {:ok, %{schema: schema_map}}
    else
      {:error, :enoent} ->
        Logger.error("[Brain.GetSchema] schema not found type=#{params.entity_type}")

        {:error, "Schema not found for type: #{params.entity_type}"}

      {:error, reason} ->
        Logger.error(fn ->
          "[Brain.GetSchema] failed type=#{params.entity_type} reason=#{inspect(reason)}"
        end)

        {:error, Helpers.format_error(reason)}
    end
  end
end
