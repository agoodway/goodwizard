defmodule Goodwizard.Scheduling.OneTimeStore do
  @moduledoc """
  File-backed persistence for one-time tasks.

  Each job is stored as a JSON file named `<job_id>.json` under
  `workspace/scheduling/one_time/`. Provides CRUD operations: save, delete,
  list, and load_all. Mirrors the ScheduledTaskStore API.
  """

  require Logger

  @job_id_pattern ~r/\Aone_time_[0-9a-f]{16}\z/

  @doc """
  Persists a one-time task record to disk.

  Creates the `scheduling/one_time/` directory if it doesn't exist.
  The record must contain a `:job_id` key (atom or string).
  """
  @spec save(map()) :: :ok | {:error, term()}
  def save(%{job_id: job_id} = record) do
    dir = one_time_dir()

    with :ok <- validate_job_id(job_id),
         :ok <- File.mkdir_p(dir) do
      path = job_path(dir, job_id)
      tmp_path = path <> ".tmp"
      json = Jason.encode!(normalize_record(record), pretty: true)

      with :ok <- File.write(tmp_path, json) do
        File.rename(tmp_path, path)
      end
    end
  end

  @doc """
  Deletes a persisted one-time task file.

  Returns `:ok` if the file was deleted or didn't exist.
  """
  @spec delete(atom() | String.t()) :: :ok | {:error, term()}
  def delete(job_id) do
    with :ok <- validate_job_id(job_id) do
      path = job_path(one_time_dir(), job_id)

      case File.rm(path) do
        :ok -> :ok
        {:error, :enoent} -> :ok
        {:error, _} = err -> err
      end
    end
  end

  @doc """
  Lists all persisted one-time task records.

  Returns `{:ok, [map()]}`. Malformed files are skipped with a warning.
  Jobs are sorted by `fires_at` ascending.
  """
  @spec list() :: {:ok, [map()]} | {:error, term()}
  def list do
    dir = one_time_dir()

    case File.ls(dir) do
      {:ok, files} ->
        jobs =
          files
          |> Enum.filter(&String.ends_with?(&1, ".json"))
          |> Enum.reduce([], fn file, acc -> collect_job(Path.join(dir, file), acc) end)
          |> Enum.sort_by(& &1["fires_at"], &<=/2)

        {:ok, jobs}

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Loads all persisted one-time task records.

  Same as `list/0` but named for consistency with ScheduledTaskStore.
  """
  @spec load_all() :: {:ok, [map()]} | {:error, term()}
  def load_all, do: list()

  @doc """
  Migrates legacy `scheduling/oneshot` data into `scheduling/one_time`.

  Behavior:
  - If legacy path exists and new path does not, move legacy -> new.
  - If both paths exist, return conflict (no silent merge).
  - Rewrite legacy `oneshot_*.json` files and `job_id` values to `one_time_*`.
  """
  @spec migrate_legacy_dir() :: :ok | {:error, :conflict | term()}
  def migrate_legacy_dir do
    workspace = Goodwizard.Config.workspace()
    legacy_dir = Path.join(workspace, "scheduling/oneshot")
    new_dir = one_time_dir()

    with :ok <- migrate_legacy_path(legacy_dir, new_dir),
         :ok <- migrate_legacy_job_ids(new_dir) do
      :ok
    end
  end

  defp one_time_dir do
    Path.join(Goodwizard.Config.workspace(), "scheduling/one_time")
  end

  defp migrate_legacy_path(legacy_dir, new_dir) do
    cond do
      File.dir?(legacy_dir) and File.dir?(new_dir) ->
        {:error, :conflict}

      File.dir?(legacy_dir) ->
        File.mkdir_p!(Path.dirname(new_dir))

        case File.rename(legacy_dir, new_dir) do
          :ok ->
            Logger.info("Migrated one-time task storage from #{legacy_dir} to #{new_dir}")
            :ok

          {:error, reason} ->
            {:error, reason}
        end

      true ->
        :ok
    end
  end

  defp migrate_legacy_job_ids(new_dir) do
    case File.ls(new_dir) do
      {:ok, files} ->
        migrate_legacy_files(new_dir, files)

      {:error, :enoent} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp migrate_legacy_files(new_dir, files) do
    files
    |> Enum.filter(&String.starts_with?(&1, "oneshot_"))
    |> Enum.reduce_while(:ok, fn file, _acc ->
      case rewrite_legacy_job_file(Path.join(new_dir, file), file) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp rewrite_legacy_job_file(path, file) do
    with {:ok, content} <- File.read(path),
         {:ok, data} <- Jason.decode(content),
         old_job_id <- Map.get(data, "job_id", String.trim_trailing(file, ".json")),
         new_job_id <- String.replace(to_string(old_job_id), "oneshot_", "one_time_"),
         updated <- Map.put(data, "job_id", new_job_id),
         :ok <- File.write(path, Jason.encode!(updated, pretty: true)),
         :ok <- File.rename(path, Path.join(Path.dirname(path), "#{new_job_id}.json")) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  def validate_job_id(job_id) do
    id_str = to_string(job_id)

    if Regex.match?(@job_id_pattern, id_str) do
      :ok
    else
      {:error, :invalid_job_id}
    end
  end

  defp job_path(dir, job_id) do
    id_str = to_string(job_id)
    Path.join(dir, "#{id_str}.json")
  end

  defp normalize_record(record) do
    record
    |> Map.new(fn {k, v} -> {to_string(k), normalize_value(v)} end)
    |> Map.update("job_id", nil, &to_string/1)
  end

  defp normalize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp normalize_value(v) when is_atom(v) and not is_nil(v) and not is_boolean(v),
    do: to_string(v)

  defp normalize_value(v), do: v

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
        Logger.warning("Skipping malformed one-time task file #{path}: #{inspect(reason)}")
        :skip
    end
  end
end
