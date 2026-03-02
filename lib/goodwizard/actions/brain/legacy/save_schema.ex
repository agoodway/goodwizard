defmodule Goodwizard.Actions.Brain.Legacy.SaveSchema do
  @moduledoc """
  Legacy `brain` alias for `save_schema`.
  """

  use Jido.Action,
    name: "save_brain_schema",
    description: "DEPRECATED legacy brain alias. Use save_schema for knowledge base schemas.",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"people\", \"companies\", \"notes\")"
      ],
      schema: [
        type: {:map, :string, :any},
        required: true,
        doc: "A valid JSON Schema object defining the entity structure"
      ]
    ]

  alias Goodwizard.Actions.Brain.SaveSchema, as: Canonical
  alias Goodwizard.KnowledgeBase.Legacy

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    Legacy.run_legacy(context, "save_brain_schema", "save_schema", fn ->
      Canonical.run(params, context)
    end)
  end
end
