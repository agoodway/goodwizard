defmodule Goodwizard.Actions.Brain.Legacy.UpdateEntity do
  @moduledoc """
  Legacy `brain` alias for `update_entity`.
  """

  use Jido.Action,
    name: "update_brain_entity",
    description: "DEPRECATED legacy brain alias. Use update_entity for knowledge base entities.",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"people\", \"companies\", \"notes\")"
      ],
      id: [type: :string, required: true, doc: "The entity ID"],
      data: [
        type: {:map, :string, :any},
        required: true,
        doc: "JSON object with fields to update"
      ],
      body: [type: :string, doc: "Optional new markdown body content (nil preserves existing)"]
    ]

  alias Goodwizard.Actions.Brain.UpdateEntity, as: Canonical
  alias Goodwizard.KnowledgeBase.Legacy

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    Legacy.run_legacy(context, "update_brain_entity", "update_entity", fn ->
      Canonical.run(params, context)
    end)
  end
end
