defmodule Goodwizard.Actions.Brain.RefreshTools do
  @moduledoc """
  Legacy `brain` alias for refreshing typed knowledge base tools.
  """

  use Jido.Action,
    name: "refresh_brain_tools",
    description: "DEPRECATED legacy brain alias. Use refresh_knowledge_base_tools instead.",
    schema: []

  alias Goodwizard.Actions.KnowledgeBase.RefreshTools, as: Canonical
  alias Goodwizard.KnowledgeBase.Legacy

  @impl true
  @spec run(map(), map()) :: {:ok, map()}
  def run(params, context) do
    Legacy.run_legacy(context, "refresh_brain_tools", "refresh_knowledge_base_tools", fn ->
      Canonical.run(params, context)
    end)
  end
end
