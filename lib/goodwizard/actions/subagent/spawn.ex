defmodule Goodwizard.Actions.Subagent.Spawn do
  @moduledoc """
  Spawns a SubAgent to execute a background task.

  Starts a SubAgent instance, sends the task query, and returns
  the result. The subagent runs as a linked Task — if the parent
  agent dies, the subagent dies too.
  """

  use Jido.Action,
    name: "spawn_subagent",
    description: "Spawn a background subagent to complete a task. The subagent has filesystem and shell tools but no browser, messaging, or spawn capabilities.",
    schema: [
      task: [type: :string, required: true, doc: "The task for the subagent to complete"],
      context: [type: :string, doc: "Optional context to provide to the subagent"]
    ]

  require Logger

  alias Goodwizard.SubAgent

  @ask_timeout 120_000

  @impl true
  def run(params, _context) do
    task_description = params.task
    task_context = Map.get(params, :context, "")

    query =
      if task_context != "" do
        "Context: #{task_context}\n\nTask: #{task_description}"
      else
        task_description
      end

    agent_id = "subagent:#{System.unique_integer([:positive])}"

    case Goodwizard.Jido.start_agent(SubAgent, id: agent_id) do
      {:ok, pid} ->
        # Run as a linked Task so it dies with the parent
        task =
          Task.async(fn ->
            SubAgent.ask_sync(pid, query, timeout: @ask_timeout)
          end)

        case Task.await(task, @ask_timeout + 5_000) do
          {:ok, result} ->
            {:ok, %{result: result}}

          {:error, reason} ->
            {:error, "Subagent failed: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Failed to start subagent: #{inspect(reason)}"}
    end
  end
end
