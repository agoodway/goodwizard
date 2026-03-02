defmodule Goodwizard.Actions.Brain.Legacy.DeleteEntity do
  @moduledoc """
  Legacy `brain` alias for `delete_entity`.
  """

  use Jido.Action,
    name: "delete_brain_entity",
    description: "DEPRECATED legacy brain alias. Use delete_entity for knowledge base entities.",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"notes\", \"contacts\")"
      ],
      id: [type: :string, required: true, doc: "The entity ID"]
    ]

  alias Goodwizard.Actions.Brain.DeleteEntity, as: Canonical
  alias Goodwizard.KnowledgeBase.Legacy

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    Legacy.run_legacy(context, "delete_brain_entity", "delete_entity", fn ->
      Canonical.run(params, context)
    end)
  end
end
