defmodule Goodwizard.SubAgent do
  @moduledoc """
  Focused background agent for delegated tasks.

  Uses Jido's ReActAgent with a constrained toolset.
  No spawn, messaging, scheduling, skill, or browser capabilities to
  prevent recursion and keep subagents lightweight.
  """

  @dialyzer {:nowarn_function, plugin_specs: 0}

  use Jido.AI.ReActAgent,
    name: "goodwizard_subagent",
    description: "Focused background agent for file processing and research tasks",
    tools: [
      Goodwizard.Actions.Filesystem.ReadFile,
      Goodwizard.Actions.Filesystem.WriteFile,
      Goodwizard.Actions.Filesystem.EditFile,
      Goodwizard.Actions.Filesystem.ListDir,
      Goodwizard.Actions.Filesystem.GrepFile,
      Goodwizard.Actions.Shell.Exec,
      # Memory
      Goodwizard.Actions.Memory.ReadLongTerm,
      Goodwizard.Actions.Memory.WriteLongTerm,
      Goodwizard.Actions.Memory.AppendHistory,
      Goodwizard.Actions.Memory.SearchHistory,
      Goodwizard.Actions.Memory.Consolidate,
      # Heartbeat
      Goodwizard.Actions.Heartbeat.UpdateChecks,
      # Brain
      Goodwizard.Actions.Brain.CreateEntity,
      Goodwizard.Actions.Brain.ReadEntity,
      Goodwizard.Actions.Brain.UpdateEntity,
      Goodwizard.Actions.Brain.DeleteEntity,
      Goodwizard.Actions.Brain.ListEntities,
      Goodwizard.Actions.Brain.GetSchema,
      Goodwizard.Actions.Brain.ListEntityTypes
    ],
    model: "anthropic:claude-sonnet-4-5",
    max_iterations: 10

  require Logger

  alias Goodwizard.SubAgent.Character

  @impl true
  def on_before_cmd(agent, {:ai_react_start, params} = _action) do
    {:ok, character} = Character.new()

    character =
      case Map.get(params, :system_prompt, "") do
        "" ->
          character

        context ->
          {:ok, updated} =
            Jido.Character.add_knowledge(character, context, category: "task-context")

          updated
      end

    system_prompt = Jido.Character.to_system_prompt(character)
    action = {:ai_react_start, Map.put(params, :system_prompt, system_prompt)}
    super(agent, action)
  end

  @impl true
  def on_before_cmd(agent, action), do: super(agent, action)
end
