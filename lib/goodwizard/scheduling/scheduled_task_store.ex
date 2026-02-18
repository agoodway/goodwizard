defmodule Goodwizard.Scheduling.ScheduledTaskStore do
  @moduledoc """
  File-backed persistence for scheduled tasks.

  Each job is stored as a JSON file named `<job_id>.json` under
  `workspace/scheduling/scheduled_tasks/`. Provides CRUD operations: save, delete,
  list, and load_all.
  """

  require Logger

  @doc """
  Persists a scheduled task record to disk.

  Creates the `scheduling/scheduled_tasks/` directory if it doesn't exist.
  The record must contain a `:job_id` key (atom or string).
  """
  @spec save(map()) :: :ok | {:error, term()}
  def save(%{job_id: job_id} = record) do
    dir = scheduled_task_dir()

    with :ok <- validate_job_id(job_id),
         :ok <- File.mkdir_p(dir) do
      path = job_path(dir, job_id)
      json = Jason.encode!(normalize_record(record), pretty: true)
      File.write(path, json)
    end
  end

  @doc """
  Deletes a persisted scheduled task file.

  Returns `:ok` if the file was deleted or didn't exist.
  """
  @spec delete(atom() | String.t()) :: :ok | {:error, term()}
  def delete(job_id) do
    with :ok <- validate_job_id(job_id) do
      path = job_path(scheduled_task_dir(), job_id)

      case File.rm(path) do
        :ok -> :ok
        {:error, :enoent} -> :ok
        {:error, _} = err -> err
      end
    end
  end

  @doc """
  Lists all persisted scheduled task records.

  Returns `{:ok, [map()]}`. Malformed files are skipped with a warning.
  """
  @spec list() :: {:ok, [map()]}
  def list do
    dir = scheduled_task_dir()

    case File.ls(dir) do
      {:ok, files} ->
        jobs =
          files
          |> Enum.filter(&String.ends_with?(&1, ".json"))
          |> Enum.reduce([], fn file, acc -> collect_job(Path.join(dir, file), acc) end)
          |> Enum.sort_by(& &1["created_at"], &<=/2)

        {:ok, jobs}

      {:error, :enoent} ->
        {:ok, []}
    end
  end

  @doc """
  Loads all persisted scheduled task records.

  Same as `list/0` but returns the raw list (for reload use).
  """
  @spec load_all() :: {:ok, [map()]}
  def load_all, do: list()

  @doc """
  Migrates legacy `scheduling/cron` storage to `scheduling/scheduled_tasks`.

  Behavior:
  - If legacy exists and new does not, rename legacy -> new.
  - If both exist, return conflict error (no silent merge).
  - If legacy does not exist, no-op.
  """
  @spec migrate_legacy_dir() :: :ok | {:error, :conflict | term()}
  def migrate_legacy_dir do
    workspace = Goodwizard.Config.workspace()
    legacy_dir = Path.join(workspace, "scheduling/cron")
    new_dir = scheduled_task_dir()

    cond do
      File.dir?(legacy_dir) and File.dir?(new_dir) ->
        {:error, :conflict}

      File.dir?(legacy_dir) ->
        File.mkdir_p!(Path.dirname(new_dir))

        case File.rename(legacy_dir, new_dir) do
          :ok ->
            Logger.info("Migrated scheduled task storage from #{legacy_dir} to #{new_dir}")
            :ok

          {:error, reason} ->
            {:error, reason}
        end

      true ->
        :ok
    end
  end

  defp scheduled_task_dir do
    Path.join(Goodwizard.Config.workspace(), "scheduling/scheduled_tasks")
  end

  defp validate_job_id(job_id) do
    id_str = to_string(job_id)

    cond do
      id_str == "" ->
        {:error, :invalid_job_id}

      String.contains?(id_str, "..") or String.contains?(id_str, "/") or
          String.contains?(id_str, <<0>>) ->
        {:error, :path_traversal}

      byte_size(id_str) > 255 ->
        {:error, :invalid_job_id}

      true ->
        :ok
    end
  end

  defp job_path(dir, job_id) do
    id_str = to_string(job_id)
    Path.join(dir, "#{id_str}.json")
  end

  defp normalize_record(record) do
    record
    |> Map.new(fn {k, v} -> {to_string(k), v} end)
    |> Map.update("job_id", nil, &to_string/1)
  end

  defp collect_job(path, acc) do
    case read_job(path) do
      {:ok, job} -> [job | acc]
      :skip -> acc
    end
  end

  defp read_job(path) do
    with {:ok, content} <- File.read(path),
         {:ok, data} <- Jason.decode(content) do
      {:ok, data}
    else
      {:error, reason} ->
        Logger.warning("Skipping malformed scheduled task file #{path}: #{inspect(reason)}")
        :skip
    end
  end
end
