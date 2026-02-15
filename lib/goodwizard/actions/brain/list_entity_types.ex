defmodule Goodwizard.Actions.Brain.ListEntityTypes do
  @moduledoc """
  Lists all available entity types in the brain knowledge base.
  """

  use Jido.Action,
    name: "list_entity_types",
    description: "List all available entity types in the brain knowledge base",
    schema: []

  require Logger

  alias Goodwizard.Actions.Brain.Helpers
  alias Goodwizard.Brain.Schema

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(_params, context) do
    workspace = get_in(context, [:state, :workspace]) || "."

    Logger.info("[Brain.ListEntityTypes] workspace=#{workspace}")

    case Schema.list_types(workspace) do
      {:ok, types} ->
        Logger.info(fn -> "[Brain.ListEntityTypes] found types=#{inspect(types)}" end)
        {:ok, %{types: types}}

      {:error, reason} ->
        Logger.error(fn -> "[Brain.ListEntityTypes] failed reason=#{inspect(reason)}" end)
        {:error, Helpers.format_error(reason)}
    end
  end
end
