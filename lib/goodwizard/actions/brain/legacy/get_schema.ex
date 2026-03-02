defmodule Goodwizard.Actions.Brain.Legacy.GetSchema do
  @moduledoc """
  Legacy `brain` alias for `get_schema`.
  """

  use Jido.Action,
    name: "get_brain_schema",
    description: "DEPRECATED legacy brain alias. Use get_schema for knowledge base schemas.",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type (e.g. \"notes\", \"contacts\")"
      ]
    ]

  alias Goodwizard.Actions.Brain.GetSchema, as: Canonical
  alias Goodwizard.KnowledgeBase.Legacy

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    Legacy.run_legacy(context, "get_brain_schema", "get_schema", fn ->
      Canonical.run(params, context)
    end)
  end
end
