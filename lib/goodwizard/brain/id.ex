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
  @id_pattern Regex.compile!("^[a-z0-9]{#{@min_length},}$")

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

  defp locked_generate(counter_file) do
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

      {:error, :eexist} ->
        Process.sleep(1)
        locked_generate(counter_file)

      {:error, reason} ->
        {:error, reason}
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
            Logger.warning("Corrupted counter file at #{path}, resetting to 0: #{inspect(String.trim(content))}")
            {:ok, 0}
        end

      {:error, :enoent} ->
        {:ok, 0}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp write_counter(path, value) do
    File.write(path, Integer.to_string(value))
  end
end
