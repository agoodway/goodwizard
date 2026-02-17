defmodule Goodwizard.Scheduling.OneShotStore do
  @moduledoc """
  File-backed persistence for one-shot scheduled tasks.

  Each job is stored as a JSON file named `<job_id>.json` under
  `workspace/scheduling/oneshot/`. Provides CRUD operations: save, delete,
  list, and load_all. Mirrors the CronStore API.
  """

  require Logger

  @job_id_pattern ~r/\Aoneshot_[0-9a-f]{16}\z/

  @doc """
  Persists a one-shot job record to disk.

  Creates the `scheduling/oneshot/` directory if it doesn't exist.
  The record must contain a `:job_id` key (atom or string).
  """
  @spec save(map()) :: :ok | {:error, term()}
  def save(%{job_id: job_id} = record) do
    dir = oneshot_dir()

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
  Deletes a persisted one-shot job file.

  Returns `:ok` if the file was deleted or didn't exist.
  """
  @spec delete(atom() | String.t()) :: :ok | {:error, term()}
  def delete(job_id) do
    with :ok <- validate_job_id(job_id) do
      path = job_path(oneshot_dir(), job_id)

      case File.rm(path) do
        :ok -> :ok
        {:error, :enoent} -> :ok
        {:error, _} = err -> err
      end
    end
  end

  @doc """
  Lists all persisted one-shot job records.

  Returns `{:ok, [map()]}`. Malformed files are skipped with a warning.
  Jobs are sorted by `fires_at` ascending.
  """
  @spec list() :: {:ok, [map()]} | {:error, term()}
  def list do
    dir = oneshot_dir()

    case File.ls(dir) do
      {:ok, files} ->
        jobs =
          files
          |> Enum.filter(&String.ends_with?(&1, ".json"))
          |> Enum.reduce([], fn file, acc ->
            case read_job(Path.join(dir, file)) do
              {:ok, job} -> [job | acc]
              :skip -> acc
            end
          end)
          |> Enum.sort_by(& &1["fires_at"], &<=/2)

        {:ok, jobs}

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Loads all persisted one-shot job records.

  Same as `list/0` but named for consistency with CronStore.
  """
  @spec load_all() :: {:ok, [map()]} | {:error, term()}
  def load_all, do: list()

  defp oneshot_dir do
    Path.join(Goodwizard.Config.workspace(), "scheduling/oneshot")
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
  defp normalize_value(v) when is_atom(v) and not is_nil(v) and not is_boolean(v), do: to_string(v)
  defp normalize_value(v), do: v

  defp read_job(path) do
    with {:ok, content} <- File.read(path),
         {:ok, data} <- Jason.decode(content) do
      {:ok, data}
    else
      {:error, reason} ->
        Logger.warning("Skipping malformed one-shot job file #{path}: #{inspect(reason)}")
        :skip
    end
  end
end
