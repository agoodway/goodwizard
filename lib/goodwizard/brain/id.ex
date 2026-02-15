defmodule Goodwizard.Brain.Id do
  @moduledoc """
  Sqids-based short unique ID generation with monotonic counter.

  Generates short, URL-friendly, lowercase alphanumeric IDs from a
  monotonic counter stored in `brain/.counter`.
  """

  require Logger

  alias Goodwizard.Brain.Paths

  @alphabet "abcdefghijklmnopqrstuvwxyz0123456789"
  @min_length 8
  @id_pattern_string "^[a-z0-9]{#{@min_length},}$"
  @id_pattern Regex.compile!(@id_pattern_string)

  @doc "Returns the ID pattern string for use in JSON Schema definitions."
  @spec id_pattern() :: String.t()
  def id_pattern, do: @id_pattern_string

  @doc """
  Generates a new unique ID by reading/incrementing the counter file
  and encoding via Sqids.

  Uses file locking to prevent race conditions when called concurrently.
  Returns `{:ok, id}` or `{:error, reason}`.
  """
  @spec generate(String.t()) :: {:ok, String.t()} | {:error, term()}
  def generate(workspace) do
    counter_file = Paths.counter_path(workspace)

    with :ok <- File.mkdir_p(Path.dirname(counter_file)) do
      locked_generate(counter_file)
    end
  end

  @max_lock_retries 10
  @base_backoff_ms 5
  @stale_lock_seconds 30

  defp locked_generate(counter_file, retries \\ 0) do
    lock_file = counter_file <> ".lock"

    case :file.open(lock_file, [:write, :exclusive]) do
      {:ok, lock_fd} ->
        try do
          with {:ok, counter} <- read_counter(counter_file),
               new_counter = counter + 1,
               {:ok, sqids} <- Sqids.new(alphabet: @alphabet, min_length: @min_length),
               id = Sqids.encode!(sqids, [new_counter]),
               :ok <- write_counter(counter_file, new_counter) do
            {:ok, id}
          end
        after
          :file.close(lock_fd)
          File.rm(lock_file)
        end

      {:error, :eexist} when retries < @max_lock_retries ->
        maybe_clean_stale_lock(lock_file)
        backoff = @base_backoff_ms * :math.pow(2, retries) |> trunc()
        jitter = :rand.uniform(max(backoff, 1))
        Process.sleep(backoff + jitter)
        locked_generate(counter_file, retries + 1)

      {:error, :eexist} ->
        {:error, :lock_timeout}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_clean_stale_lock(lock_file) do
    case File.stat(lock_file) do
      {:ok, %{mtime: mtime}} ->
        lock_age = NaiveDateTime.diff(NaiveDateTime.utc_now(), NaiveDateTime.from_erl!(mtime))

        if lock_age > @stale_lock_seconds do
          Logger.warning("Removing stale lock file at #{lock_file} (age: #{lock_age}s)")
          File.rm(lock_file)
        end

      {:error, _} ->
        :ok
    end
  end

  @doc """
  Validates that a string matches the Sqid ID pattern (lowercase alphanumeric, min 8 chars).
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(id) when is_binary(id), do: Regex.match?(@id_pattern, id)
  def valid?(_), do: false

  defp read_counter(path) do
    case File.read(path) do
      {:ok, content} ->
        case Integer.parse(String.trim(content)) do
          {n, ""} ->
            {:ok, n}

          _ ->
            Logger.warning("Corrupted counter file at #{path}: #{inspect(String.trim(content))}, recovering from existing entities")
            recover_counter(path)
        end

      {:error, :enoent} ->
        {:ok, 0}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp recover_counter(counter_path) do
    brain_dir = Path.dirname(counter_path)

    case File.ls(brain_dir) do
      {:ok, entries} ->
        max_id =
          entries
          |> Enum.filter(&File.dir?(Path.join(brain_dir, &1)))
          |> Enum.reject(&String.starts_with?(&1, "."))
          |> Enum.reject(&(&1 == "schemas"))
          |> Enum.flat_map(fn type_dir ->
            type_path = Path.join(brain_dir, type_dir)

            case File.ls(type_path) do
              {:ok, files} ->
                files
                |> Enum.filter(&String.ends_with?(&1, ".md"))
                |> Enum.map(&String.replace_suffix(&1, ".md", ""))

              _ ->
                []
            end
          end)
          |> Enum.flat_map(fn id ->
            case Sqids.new(alphabet: @alphabet, min_length: @min_length) do
              {:ok, sqids} ->
                try do
                  case Sqids.decode!(sqids, id) do
                    [n] -> [n]
                    _ -> []
                  end
                rescue
                  _ -> []
                end

              _ ->
                []
            end
          end)
          |> Enum.max(fn -> 0 end)

        Logger.info("Counter recovered to #{max_id} from existing entities")
        {:ok, max_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp write_counter(path, value) do
    tmp_path = path <> ".tmp"

    with :ok <- File.write(tmp_path, Integer.to_string(value)) do
      File.rename(tmp_path, path)
    end
  end
end
