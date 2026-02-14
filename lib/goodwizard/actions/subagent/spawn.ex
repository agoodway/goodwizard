defmodule Goodwizard.Actions.Subagent.Spawn do
  @moduledoc """
  Spawns a SubAgent to execute a background task.

  Starts a SubAgent instance under the Jido Task.Supervisor, sends
  the task query, and returns the result. The subagent process is
  cleaned up after completion regardless of success or failure.
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
  @max_concurrent_subagents 3

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

    active_count = Goodwizard.Jido.agent_count()

    if active_count >= @max_concurrent_subagents do
      {:error, "Concurrent subagent limit reached (max #{@max_concurrent_subagents}). Wait for existing subagents to complete."}
    else
      spawn_and_run(query)
    end
  end

  defp spawn_and_run(query) do
    agent_id = "subagent:#{System.unique_integer([:positive])}"

    case Goodwizard.Jido.start_agent(SubAgent, id: agent_id) do
      {:ok, pid} ->
        task =
          Task.Supervisor.async(Goodwizard.Jido.task_supervisor_name(), fn ->
            SubAgent.ask_sync(pid, query, timeout: @ask_timeout)
          end)

        try do
          case Task.await(task, @ask_timeout + 5_000) do
            {:ok, result} ->
              {:ok, %{result: result}}

            {:error, reason} ->
              {:error, "Subagent failed: #{inspect(reason)}"}
          end
        after
          Goodwizard.Jido.stop_agent(pid)
        end

      {:error, reason} ->
        {:error, "Failed to start subagent: #{inspect(reason)}"}
    end
  end
end
