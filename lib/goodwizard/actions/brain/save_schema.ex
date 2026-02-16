defmodule Goodwizard.Actions.Brain.SaveSchema do
  @moduledoc """
  Saves a JSON Schema for an entity type to the brain knowledge base.
  """

  use Jido.Action,
    name: "save_schema",
    description: "Save or update a JSON Schema definition for an entity type in the brain",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"people\", \"companies\", \"notes\")"
      ],
      schema: [
        type: {:map, :string, :any},
        required: true,
        doc: "A valid JSON Schema object defining the entity structure"
      ]
    ]

  alias Goodwizard.Actions.Brain.Helpers
  alias Goodwizard.Brain.{Schema, ToolGenerator}

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    workspace = Helpers.workspace(context)

    with :ok <- validate_schema_structure(params.schema) do
      case Schema.save(workspace, params.entity_type, params.schema) do
        :ok ->
          Goodwizard.Cache.delete("brain:schema_summaries:#{workspace}")

          tool_msg =
            case ToolGenerator.generate_for_type(workspace, params.entity_type) do
              {:ok, _modules} -> "Typed tools regenerated — available next turn."
              {:error, reason} -> "Tool generation failed (#{inspect(reason)}) — generic tools still available."
            end

          {:ok, %{message: "Schema saved for type: #{params.entity_type}. #{tool_msg}"}}

        {:error, reason} ->
          {:error, Helpers.format_error(reason)}
      end
    end
  end

  defp validate_schema_structure(schema) when is_map(schema) do
    ExJsonSchema.Schema.resolve(schema)
    :ok
  rescue
    _ -> {:error, "Invalid JSON Schema: schema could not be resolved"}
  end
end
