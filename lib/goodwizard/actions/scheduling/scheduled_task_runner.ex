defmodule Goodwizard.Actions.Scheduling.ScheduledTaskRunner do
  @moduledoc """
  Runs an isolated scheduled task in a child SubAgent.

  Spawns a fresh agent, sends the task as a query, saves the response
  to the target Messaging room, and cleans up. Each invocation is
  independent — no state persists between ticks.
  """

  require Logger

  alias Goodwizard.Messaging
  alias Goodwizard.Messaging.Delivery
  alias Goodwizard.SubAgent

  @default_ask_timeout 120_000
  @default_max_concurrent 50

  defp ask_timeout do
    Goodwizard.Config.get(["scheduled_tasks", "ask_timeout"]) || @default_ask_timeout
  end

  defp max_concurrent_scheduled_task_agents do
    Goodwizard.Config.get(["scheduled_tasks", "max_concurrent_agents"]) || @default_max_concurrent
  end

  @doc """
  Execute a scheduled task in an isolated child agent.

  Spawns a SubAgent, sends the task query, saves the response to the
  Messaging room, and stops the agent. Returns `{:ok, response}` on
  success or `{:error, reason}` on failure.

  ## Options

    * `:model` - LLM model override for the child agent
  """
  @spec run_isolated(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def run_isolated(task, room_id, opts \\ []) do
    case try_spawn(task, room_id, opts) do
      {:ok, pid, query, room_id} -> run_query_and_save(pid, query, room_id)
      {:error, _} = error -> error
    end
  end

  defp try_spawn(task, room_id, opts) do
    active_count = count_isolated_scheduled_task_agents()

    if active_count >= max_concurrent_scheduled_task_agents() do
      Logger.warning(
        "Isolated scheduled task skipped: concurrent agent limit reached (#{active_count}/#{max_concurrent_scheduled_task_agents()})"
      )

      error_text =
        "[Scheduled Task Error] Scheduled task skipped: too many concurrent tasks running."

      save_error_message(room_id, "Scheduled task skipped: too many concurrent tasks running.")
      deliver(room_id, error_text)
      {:error, :at_capacity}
    else
      do_spawn(task, room_id, opts)
    end
  end

  defp do_spawn(task, room_id, opts) do
    model = Keyword.get(opts, :model)
    workspace = Goodwizard.Config.workspace()
    query = "Workspace: #{workspace}\n\nScheduled Task: #{task}"
    agent_id = "scheduled_task:isolated:#{System.unique_integer([:positive])}"

    agent_opts =
      [id: agent_id]
      |> maybe_add_model(model)

    case Goodwizard.Jido.start_agent(SubAgent, agent_opts) do
      {:ok, pid} ->
        {:ok, pid, query, room_id}

      {:error, reason} ->
        Logger.error("Failed to start isolated scheduled task agent: #{inspect(reason)}")

        error_text =
          "[Scheduled Task Error] Scheduled task could not start. Check server logs for details."

        save_error_message(
          room_id,
          "Scheduled task could not start. Check server logs for details."
        )

        deliver(room_id, error_text)
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
          deliver(room_id, response)
          {:ok, response}

        {:error, reason} ->
          Logger.error("Isolated scheduled task failed: #{inspect(reason)}")

          error_text =
            "[Scheduled Task Error] Scheduled task failed. Check server logs for details."

          save_error_message(room_id, "Scheduled task failed. Check server logs for details.")
          deliver(room_id, error_text)
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Isolated scheduled task crashed: #{Exception.message(e)}")

        error_text =
          "[Scheduled Task Error] Scheduled task encountered an unexpected error. Check server logs for details."

        save_error_message(
          room_id,
          "Scheduled task encountered an unexpected error. Check server logs for details."
        )

        deliver(room_id, error_text)
        {:error, e}
    after
      Goodwizard.Jido.stop_agent(pid)
    end
  end

  defp deliver(room_id, content) do
    results = Delivery.deliver_to_bindings(room_id, content)

    Enum.each(results, fn
      {:ok, channel} ->
        Logger.info("Scheduled task delivery to #{channel} for room #{room_id} succeeded")

      {:error, channel, reason} ->
        Logger.warning(
          "Scheduled task delivery to #{channel} for room #{room_id} failed: #{inspect(reason)}"
        )
    end)
  end

  defp save_response(room_id, response) do
    save_message_with_retry(room_id, %{
      room_id: room_id,
      sender_id: "scheduled_task:isolated",
      role: :assistant,
      content: [%{type: "text", text: response}]
    })
  end

  defp save_error_message(room_id, message) do
    save_message_with_retry(room_id, %{
      room_id: room_id,
      sender_id: "scheduled_task:isolated",
      role: :assistant,
      content: [%{type: "text", text: "[Scheduled Task Error] #{message}"}]
    })
  end

  @max_save_retries 2

  defp save_message_with_retry(room_id, msg, attempt \\ 1) do
    case Messaging.save_message(msg) do
      {:ok, _msg} ->
        :ok

      {:error, reason} when attempt < @max_save_retries ->
        Logger.warning(
          "Failed to save message to room #{room_id} (attempt #{attempt}/#{@max_save_retries}): #{inspect(reason)}"
        )

        Process.sleep(100 * attempt)
        save_message_with_retry(room_id, msg, attempt + 1)

      {:error, reason} ->
        Logger.error(
          "Failed to save message to room #{room_id} after #{@max_save_retries} attempts: #{inspect(reason)}"
        )
    end
  end

  defp count_isolated_scheduled_task_agents do
    Goodwizard.Jido.list_agents()
    |> Enum.count(fn {id, _pid} -> String.starts_with?(id, "scheduled_task:isolated:") end)
  end

  defp maybe_add_model(opts, nil), do: opts

  defp maybe_add_model(opts, model) do
    Keyword.put(opts, :initial_state, %{model: model})
  end
end
