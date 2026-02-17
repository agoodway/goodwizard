defmodule Goodwizard.Scheduling.OneShotLoader do
  @moduledoc """
  Reloads persisted one-shot jobs on application startup.

  Reads all persisted jobs from `OneShotStore.load_all/0`, discards any
  whose `fires_at` is in the past, and re-schedules pending jobs with
  an adjusted remaining delay via `:timer.apply_after`.

  Malformed files are skipped with a warning — the application starts
  normally even if some job files are corrupt.
  """

  require Logger

  alias Goodwizard.Scheduling.{OneShotStore, OneShotRegistry}
  alias Goodwizard.Actions.Scheduling.OneShot

  @job_id_pattern ~r/\Aoneshot_[0-9a-f]{16}\z/

  @doc """
  Reloads all persisted one-shot jobs.

  Returns `{:ok, count}` with the number of jobs reloaded.
  """
  @spec reload() :: {:ok, non_neg_integer()} | {:error, term()}
  def reload do
    case OneShotStore.load_all() do
      {:ok, []} ->
        Logger.info("OneShotLoader: no persisted one-shot jobs to reload")
        {:ok, 0}

      {:ok, jobs} ->
        count = reload_jobs(jobs)
        Logger.info("OneShotLoader: reloaded #{count} one-shot job(s)")
        {:ok, count}

      {:error, reason} ->
        Logger.warning("OneShotLoader: failed to load persisted jobs: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp reload_jobs(jobs) do
    now = DateTime.utc_now()

    Enum.reduce(jobs, 0, fn job, count ->
      case reload_job(job, now) do
        :ok -> count + 1
        :skip -> count
      end
    end)
  end

  defp reload_job(job, now) do
    with {:ok, job_id_str} <- validate_job_id(job["job_id"]),
         {:ok, task} <- extract_field(job, "task"),
         {:ok, room_id} <- extract_field(job, "room_id"),
         {:ok, agent_id} <- extract_field(job, "agent_id"),
         {:ok, fires_at} <- parse_fires_at(job["fires_at"]) do
      remaining_ms = DateTime.diff(fires_at, now, :millisecond)

      if remaining_ms > 0 do
        schedule_job(job_id_str, task, room_id, agent_id, fires_at, remaining_ms)
      else
        # Expired — discard the file
        Logger.warning(
          "OneShotLoader: discarding expired job #{job_id_str} (fires_at: #{job["fires_at"]})"
        )

        OneShotStore.delete(job_id_str)
        :skip
      end
    else
      {:error, reason} ->
        Logger.warning("OneShotLoader: skipping malformed job record: #{inspect(reason)}")
        :skip
    end
  end

  defp schedule_job(job_id_str, task, room_id, agent_id, _fires_at, remaining_ms) do
    job_id =
      try do
        String.to_existing_atom(job_id_str)
      rescue
        ArgumentError -> String.to_atom(job_id_str)
      end

    message = %{type: "cron.task", task: task, room_id: room_id}

    signal =
      Jido.AgentServer.Signal.CronTick.new!(
        %{job_id: job_id, message: message},
        source: "/agent/#{agent_id}"
      )

    case :timer.apply_after(remaining_ms, OneShot, :deliver, [agent_id, signal, job_id]) do
      {:ok, tref} ->
        OneShotRegistry.register(job_id, tref)

        Logger.debug(
          "OneShotLoader: reloaded #{job_id_str} (fires in #{div(remaining_ms, 1000)}s)"
        )

        :ok

      {:error, reason} ->
        Logger.warning("OneShotLoader: failed to schedule #{job_id_str}: #{inspect(reason)}")
        :skip
    end
  end

  defp validate_job_id(nil), do: {:error, "missing field: job_id"}

  defp validate_job_id(job_id_str) when is_binary(job_id_str) do
    if Regex.match?(@job_id_pattern, job_id_str) do
      {:ok, job_id_str}
    else
      {:error, "invalid job_id format: #{inspect(job_id_str)}"}
    end
  end

  defp extract_field(job, field) do
    case Map.get(job, field) do
      nil -> {:error, "missing field: #{field}"}
      "" -> {:error, "empty field: #{field}"}
      value -> {:ok, value}
    end
  end

  defp parse_fires_at(nil), do: {:error, "missing field: fires_at"}

  defp parse_fires_at(fires_at_str) when is_binary(fires_at_str) do
    case DateTime.from_iso8601(fires_at_str) do
      {:ok, dt, _offset} -> {:ok, dt}
      {:error, _} -> {:error, "invalid fires_at: #{inspect(fires_at_str)}"}
    end
  end
end
