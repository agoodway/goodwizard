defmodule Goodwizard.Actions.Brain.Legacy.CreateEntity do
  @moduledoc """
  Legacy `brain` alias for `create_entity`.
  """

  use Jido.Action,
    name: "create_brain_entity",
    description: "DEPRECATED legacy brain alias. Use create_entity for knowledge base entities.",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"people\", \"companies\", \"notes\")"
      ],
      data: [
        type: {:map, :string, :any},
        required: true,
        doc: "JSON object with fields matching the entity type schema"
      ],
      body: [type: :string, default: "", doc: "Optional markdown body content"]
    ]

  alias Goodwizard.Actions.Brain.CreateEntity, as: Canonical
  alias Goodwizard.KnowledgeBase.Legacy

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    Legacy.run_legacy(context, "create_brain_entity", "create_entity", fn ->
      Canonical.run(params, context)
    end)
  end
end
