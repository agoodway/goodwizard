defmodule Goodwizard.Actions.Memory.SearchHistory do
  @moduledoc """
  Searches HISTORY.md for lines matching a pattern (case-insensitive).
  """

  use Jido.Action,
    name: "search_history",
    description: "Search conversation history (HISTORY.md) for matching entries",
    schema: [
      memory_dir: [type: :string, required: true, doc: "Path to the memory directory"],
      pattern: [type: :string, required: true, doc: "Search pattern (case-insensitive)"]
    ]

  alias Goodwizard.Memory.Paths

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, _context) do
    with {:ok, _} <- Paths.validate_memory_dir(params.memory_dir) do
      path = Paths.history_path(params.memory_dir)
      matches = search_file(path, params.pattern)
      {:ok, %{matches: matches}}
    end
  end

  defp search_file(path, pattern) do
    downcased_pattern = String.downcase(pattern)

    case File.read(path) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.map(&String.trim_trailing/1)
        |> Enum.filter(fn line ->
          String.contains?(String.downcase(line), downcased_pattern)
        end)

      {:error, _} ->
        []
    end
  end
end
