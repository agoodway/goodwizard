defmodule Goodwizard.Actions.Brain.RefreshTools do
  @moduledoc """
  Regenerates typed brain tools after schema changes.

  Call this after modifying schemas to make updated create/update tools
  available on the next conversation turn.
  """

  use Jido.Action,
    name: "refresh_brain_tools",
    description:
      "Regenerate typed brain tools when schemas were changed outside the agent " <>
        "(e.g. manual file edits, git pulls). Not needed after save_schema, which auto-regenerates.",
    schema: []

  alias Goodwizard.Actions.Brain.Helpers
  alias Goodwizard.Brain.ToolGenerator

  @impl true
  @spec run(map(), map()) :: {:ok, map()}
  def run(_params, context) do
    workspace = Helpers.workspace(context)
    {:ok, modules} = ToolGenerator.generate_all(workspace)
    tool_names = Enum.map(modules, & &1.name())
    {:ok, %{message: "Regenerated #{length(modules)} brain tools", tools: tool_names}}
  end
end
