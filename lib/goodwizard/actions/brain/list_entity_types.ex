defmodule Goodwizard.Actions.Brain.ListEntityTypes do
  @moduledoc """
  Lists all available entity types in the brain knowledge base.
  """

  use Jido.Action,
    name: "list_entity_types",
    description: "List all available entity types in the brain knowledge base",
    schema: []

  alias Goodwizard.Brain.Schema

  @impl true
  def run(_params, context) do
    workspace = get_in(context, [:state, :workspace]) || "."

    case Schema.list_types(workspace) do
      {:ok, types} ->
        {:ok, %{types: types, count: length(types)}}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
