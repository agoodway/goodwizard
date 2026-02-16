defmodule Goodwizard.Actions.Brain.RefreshTools do
  @moduledoc """
  Regenerates typed brain tools after schema changes.

  Call this after modifying schemas to make updated create/update tools
  available on the next conversation turn.
  """

  use Jido.Action,
    name: "refresh_brain_tools",
    description:
      "Regenerate typed brain tools after schema changes. " <>
        "Call after save_schema to pick up new or modified entity types.",
    schema: []

  alias Goodwizard.Actions.Brain.Helpers
  alias Goodwizard.Brain.ToolGenerator

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(_params, context) do
    workspace = Helpers.workspace(context)
    {:ok, modules} = ToolGenerator.generate_all(workspace)
    tool_names = Enum.map(modules, & &1.name())
    {:ok, %{message: "Regenerated #{length(modules)} brain tools", tools: tool_names}}
  end
end
