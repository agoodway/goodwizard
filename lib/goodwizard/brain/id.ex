defmodule Goodwizard.Brain.Id do
  @moduledoc """
  Sqids-based short unique ID generation with monotonic counter.

  Generates short, URL-friendly, lowercase alphanumeric IDs from a
  monotonic counter stored in `brain/.counter`.
  """

  alias Goodwizard.Brain.Paths

  @alphabet "abcdefghijklmnopqrstuvwxyz0123456789"
  @min_length 8
  @id_pattern ~r/^[a-z0-9]{8,}$/

  @doc """
  Generates a new unique ID by reading/incrementing the counter file
  and encoding via Sqids.

  Returns `{:ok, id}` or `{:error, reason}`.
  """
  @spec generate(String.t()) :: {:ok, String.t()} | {:error, term()}
  def generate(workspace) do
    counter_file = Paths.counter_path(workspace)

    with :ok <- File.mkdir_p(Path.dirname(counter_file)),
         {:ok, counter} <- read_counter(counter_file),
         new_counter = counter + 1,
         {:ok, sqids} <- Sqids.new(alphabet: @alphabet, min_length: @min_length),
         id = Sqids.encode!(sqids, [new_counter]),
         :ok <- write_counter(counter_file, new_counter) do
      {:ok, id}
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
          {n, ""} -> {:ok, n}
          _ -> {:ok, 0}
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
