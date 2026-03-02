defmodule Goodwizard.Actions.Brain.Legacy.ListEntities do
  @moduledoc """
  Legacy `brain` alias for `list_entities`.
  """

  use Jido.Action,
    name: "list_brain_entities",
    description: "DEPRECATED legacy brain alias. Use list_entities for knowledge base entities.",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"notes\", \"contacts\")"
      ]
    ]

  alias Goodwizard.Actions.Brain.ListEntities, as: Canonical
  alias Goodwizard.KnowledgeBase.Legacy

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    Legacy.run_legacy(context, "list_brain_entities", "list_entities", fn ->
      Canonical.run(params, context)
    end)
  end
end
