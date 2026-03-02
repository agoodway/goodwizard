defmodule Goodwizard.Actions.Brain.Legacy.ListEntityTypes do
  @moduledoc """
  Legacy `brain` alias for `list_entity_types`.
  """

  use Jido.Action,
    name: "list_brain_entity_types",
    description:
      "DEPRECATED legacy brain alias. Use list_entity_types for knowledge base schemas.",
    schema: []

  alias Goodwizard.Actions.Brain.ListEntityTypes, as: Canonical
  alias Goodwizard.KnowledgeBase.Legacy

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    Legacy.run_legacy(context, "list_brain_entity_types", "list_entity_types", fn ->
      Canonical.run(params, context)
    end)
  end
end
