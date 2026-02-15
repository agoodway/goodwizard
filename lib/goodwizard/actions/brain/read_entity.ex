defmodule Goodwizard.Actions.Brain.ReadEntity do
  @moduledoc """
  Reads an entity from the brain knowledge base by type and ID.
  """

  use Jido.Action,
    name: "read_entity",
    description: "Read an entity by type and ID from the brain knowledge base",
    schema: [
      entity_type: [type: :string, required: true, doc: "The entity type (e.g. \"notes\", \"contacts\")"],
      id: [type: :string, required: true, doc: "The entity ID"]
    ]

  @impl true
  def run(params, context) do
    workspace = get_in(context, [:state, :workspace]) || "."

    case Goodwizard.Brain.read(workspace, params.entity_type, params.id) do
      {:ok, {data, body}} ->
        {:ok, %{data: data, body: body}}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
