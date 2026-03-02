defmodule Goodwizard.Actions.Brain.Legacy.ReadEntity do
  @moduledoc """
  Legacy `brain` alias for `read_entity`.
  """

  use Jido.Action,
    name: "read_brain_entity",
    description: "DEPRECATED legacy brain alias. Use read_entity for knowledge base entities.",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"notes\", \"contacts\")"
      ],
      id: [type: :string, required: true, doc: "The entity ID"]
    ]

  alias Goodwizard.Actions.Brain.ReadEntity, as: Canonical
  alias Goodwizard.KnowledgeBase.Legacy

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    Legacy.run_legacy(context, "read_brain_entity", "read_entity", fn ->
      Canonical.run(params, context)
    end)
  end
end
