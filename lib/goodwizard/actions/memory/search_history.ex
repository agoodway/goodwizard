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

  @impl true
  def run(params, _context) do
    path = Path.join(params.memory_dir, "HISTORY.md")
    downcased_pattern = String.downcase(params.pattern)

    matches =
      if File.exists?(path) do
        path
        |> File.stream!()
        |> Stream.map(&String.trim_trailing/1)
        |> Enum.filter(fn line ->
          String.contains?(String.downcase(line), downcased_pattern)
        end)
      else
        []
      end

    {:ok, %{matches: matches}}
  end
end
