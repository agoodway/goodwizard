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

    schema = ensure_metadata_property(params.schema)

    with :ok <- validate_schema_structure(schema) do
      case Schema.save(workspace, params.entity_type, schema) do
        :ok ->
          Goodwizard.Cache.delete("brain:schema_summaries:#{workspace}")
          tool_msg = regenerate_tools(workspace, params.entity_type)
          {:ok, %{message: "Schema saved for type: #{params.entity_type}. #{tool_msg}"}}

        {:error, reason} ->
          {:error, Helpers.format_error(reason)}
      end
    end
  end

  @default_metadata_property %{
    "type" => "object",
    "additionalProperties" => %{"type" => "string", "maxLength" => 1000},
    "propertyNames" => %{"pattern" => "^[a-zA-Z0-9_.-]{1,64}$"},
    "maxProperties" => 50,
    "description" => "Arbitrary key-value string metadata"
  }

  defp ensure_metadata_property(schema) do
    schema
    |> put_in_if_missing(["properties", "metadata"], @default_metadata_property)
    |> ensure_required("metadata")
  end

  defp put_in_if_missing(schema, ["properties", "metadata"], default) do
    props = Map.get(schema, "properties", %{})

    if Map.has_key?(props, "metadata") do
      schema
    else
      Map.put(schema, "properties", Map.put(props, "metadata", default))
    end
  end

  defp ensure_required(schema, field) do
    required = Map.get(schema, "required", [])

    if field in required do
      schema
    else
      Map.put(schema, "required", required ++ [field])
    end
  end

  defp regenerate_tools(workspace, entity_type) do
    case ToolGenerator.generate_for_type(workspace, entity_type) do
      {:ok, _modules} ->
        "Typed tools regenerated — available next turn."

      {:error, reason} ->
        "Tool generation failed (#{inspect(reason)}) — generic tools still available."
    end
  end

  defp validate_schema_structure(schema) when is_map(schema) do
    ExJsonSchema.Schema.resolve(schema)
    :ok
  rescue
    _ -> {:error, "Invalid JSON Schema: schema could not be resolved"}
  end
end
