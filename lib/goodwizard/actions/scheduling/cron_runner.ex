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

  @default_ask_timeout 120_000
  @default_max_concurrent 3

  defp ask_timeout do
    Goodwizard.Config.get(["cron", "ask_timeout"]) || @default_ask_timeout
  end

  defp max_concurrent_cron_agents do
    Goodwizard.Config.get(["cron", "max_concurrent_agents"]) || @default_max_concurrent
  end

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
    # Serialize the capacity check + agent spawn to prevent TOCTOU races.
    # :global.trans ensures only one caller at a time enters this section.
    case :global.trans({__MODULE__, :spawn_lock}, fn -> try_spawn(task, room_id, opts) end) do
      {:ok, pid, query, room_id} -> run_query_and_save(pid, query, room_id)
      {:error, _} = error -> error
    end
  end

  defp try_spawn(task, room_id, opts) do
    active_count = Goodwizard.Jido.agent_count()

    if active_count >= max_concurrent_cron_agents() do
      Logger.warning(
        "Isolated cron skipped: concurrent agent limit reached (#{active_count}/#{max_concurrent_cron_agents()})"
      )

      save_error_message(room_id, "Cron task skipped: too many concurrent tasks running.")
      {:error, :at_capacity}
    else
      do_spawn(task, room_id, opts)
    end
  end

  defp do_spawn(task, room_id, opts) do
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
        {:ok, pid, query, room_id}

      {:error, reason} ->
        Logger.error("Failed to start isolated cron agent: #{inspect(reason)}")
        save_error_message(room_id, "Cron task could not start. Check server logs for details.")
        {:error, reason}
    end
  end

  defp run_query_and_save(pid, query, room_id) do
    task_ref =
      Task.Supervisor.async(Goodwizard.Jido.task_supervisor_name(), fn ->
        SubAgent.ask_sync(pid, query, timeout: ask_timeout())
      end)

    try do
      case Task.await(task_ref, ask_timeout() + 5_000) do
        {:ok, response} ->
          save_response(room_id, response)
          {:ok, response}

        {:error, reason} ->
          Logger.error("Isolated cron task failed: #{inspect(reason)}")
          save_error_message(room_id, "Cron task failed. Check server logs for details.")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Isolated cron task crashed: #{Exception.message(e)}")
        save_error_message(room_id, "Cron task encountered an unexpected error. Check server logs for details.")
        {:error, e}
    after
      Goodwizard.Jido.stop_agent(pid)
    end
  end

  defp save_response(room_id, response) do
    case Messaging.save_message(%{
           room_id: room_id,
           sender_id: "cron:isolated",
           role: :assistant,
           content: [%{type: "text", text: response}]
         }) do
      {:ok, _msg} -> :ok
      {:error, reason} -> Logger.warning("Failed to save cron response to room #{room_id}: #{inspect(reason)}")
    end
  end

  defp save_error_message(room_id, message) do
    case Messaging.save_message(%{
           room_id: room_id,
           sender_id: "cron:isolated",
           role: :assistant,
           content: [%{type: "text", text: "[Cron Error] #{message}"}]
         }) do
      {:ok, _msg} -> :ok
      {:error, reason} -> Logger.warning("Failed to save cron error to room #{room_id}: #{inspect(reason)}")
    end
  end

  defp maybe_add_model(opts, nil), do: opts

  defp maybe_add_model(opts, model) do
    Keyword.put(opts, :initial_state, %{model: model})
  end
end
