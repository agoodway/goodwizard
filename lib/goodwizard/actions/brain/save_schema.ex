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

  alias Goodwizard.Brain.Schema

  @impl true
  def run(params, context) do
    workspace = get_in(context, [:state, :workspace]) || "."

    case Schema.save(workspace, params.entity_type, params.schema) do
      :ok ->
        {:ok, %{message: "Schema saved for type: #{params.entity_type}"}}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
