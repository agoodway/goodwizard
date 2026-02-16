defmodule Goodwizard.Actions.Scheduling.CronRunner do
  @moduledoc """
  Runs an isolated cron task in a child SubAgent.

  Spawns a fresh agent, sends the task as a query, saves the response
  to the target Messaging room, and cleans up. Each invocation is
  independent — no state persists between ticks.
  """

  require Logger

  alias Goodwizard.Messaging
  alias Goodwizard.SubAgent

  @ask_timeout 120_000
  @max_concurrent_cron_agents 3

  @doc """
  Execute a cron task in an isolated child agent.

  Spawns a SubAgent, sends the task query, saves the response to the
  Messaging room, and stops the agent. Returns `{:ok, response}` on
  success or `{:error, reason}` on failure.

  ## Options

    * `:model` - LLM model override for the child agent
  """
  @spec run_isolated(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def run_isolated(task, room_id, opts \\ []) do
    active_count = Goodwizard.Jido.agent_count()

    if active_count >= @max_concurrent_cron_agents do
      msg =
        "Isolated cron skipped: concurrent agent limit reached (#{active_count}/#{@max_concurrent_cron_agents})"

      Logger.warning(msg)
      save_error_message(room_id, msg)
      {:error, :at_capacity}
    else
      do_run_isolated(task, room_id, opts)
    end
  end

  defp do_run_isolated(task, room_id, opts) do
    model = Keyword.get(opts, :model)
    workspace = Goodwizard.Config.workspace()

    query =
      "Workspace: #{workspace}\n\nCron Task: #{task}"

    agent_id = "cron:isolated:#{System.unique_integer([:positive])}"

    agent_opts =
      [id: agent_id]
      |> maybe_add_model(model)

    case Goodwizard.Jido.start_agent(SubAgent, agent_opts) do
      {:ok, pid} ->
        run_query_and_save(pid, query, room_id)

      {:error, reason} ->
        msg = "Failed to start isolated cron agent: #{inspect(reason)}"
        Logger.error(msg)
        save_error_message(room_id, msg)
        {:error, reason}
    end
  end

  defp run_query_and_save(pid, query, room_id) do
    task_ref =
      Task.Supervisor.async(Goodwizard.Jido.task_supervisor_name(), fn ->
        SubAgent.ask_sync(pid, query, timeout: @ask_timeout)
      end)

    try do
      case Task.await(task_ref, @ask_timeout + 5_000) do
        {:ok, response} ->
          save_response(room_id, response)
          {:ok, response}

        {:error, reason} ->
          msg = "Isolated cron task failed: #{inspect(reason)}"
          Logger.error(msg)
          save_error_message(room_id, msg)
          {:error, reason}
      end
    rescue
      e ->
        msg = "Isolated cron task crashed: #{Exception.message(e)}"
        Logger.error(msg)
        save_error_message(room_id, msg)
        {:error, e}
    after
      Goodwizard.Jido.stop_agent(pid)
    end
  end

  defp save_response(room_id, response) do
    Messaging.save_message(%{
      room_id: room_id,
      sender_id: "cron:isolated",
      role: :assistant,
      content: [%{type: "text", text: response}]
    })
  end

  defp save_error_message(room_id, message) do
    Messaging.save_message(%{
      room_id: room_id,
      sender_id: "cron:isolated",
      role: :assistant,
      content: [%{type: "text", text: "[Cron Error] #{message}"}]
    })
  end

  defp maybe_add_model(opts, nil), do: opts

  defp maybe_add_model(opts, model) do
    Keyword.put(opts, :initial_state, %{model_override: model})
  end
end
