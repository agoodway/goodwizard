defmodule Goodwizard.Actions.Brain.ListEntityTypes do
  @moduledoc """
  Lists all available entity types in the knowledge base.
  """

  use Jido.Action,
    name: "list_entity_types",
    description: "List all available entity types in the knowledge base",
    schema: []

  alias Goodwizard.Actions.Brain.Helpers
  alias Goodwizard.Brain.Schema

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(_params, context) do
    workspace = Helpers.workspace(context)

    case Schema.list_types(workspace) do
      {:ok, types} ->
        {:ok, %{types: types}}

      {:error, reason} ->
        {:error, Helpers.format_error(reason)}
    end
  end
end
