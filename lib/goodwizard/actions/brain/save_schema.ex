defmodule Goodwizard.Actions.Brain.SaveSchema do
  @moduledoc """
  Saves a JSON Schema for an entity type to the brain knowledge base.
  """

  use Jido.Action,
    name: "save_schema",
    description: "Save a JSON Schema definition for an entity type",
    schema: [
      entity_type: [type: :string, required: true, doc: "The entity type (e.g. \"notes\", \"contacts\")"],
      schema: [type: :map, required: true, doc: "The JSON Schema definition as a map"]
    ]

  alias Goodwizard.Actions.Brain.Helpers
  alias Goodwizard.Brain.Schema

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    workspace = get_in(context, [:state, :workspace]) || "."

    with :ok <- validate_schema_structure(params.schema) do
      case Schema.save(workspace, params.entity_type, params.schema) do
        :ok ->
          {:ok, %{message: "Schema saved for type: #{params.entity_type}"}}

        {:error, reason} ->
          {:error, Helpers.format_error(reason)}
      end
    end
  end

  defp validate_schema_structure(schema) when is_map(schema) do
    try do
      ExJsonSchema.Schema.resolve(schema)
      :ok
    rescue
      _ -> {:error, "Invalid JSON Schema: schema could not be resolved"}
    end
  end
end
