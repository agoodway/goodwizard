defmodule Goodwizard.Actions.Memory.ReadLongTerm do
  @moduledoc """
  Reads the current MEMORY.md content from the agent's long-term memory.
  """

  use Jido.Action,
    name: "read_long_term",
    description: "Read the agent's long-term memory (MEMORY.md content)",
    schema: [
      memory_dir: [type: :string, required: true, doc: "Path to the memory directory"]
    ]

  @impl true
  def run(params, _context) do
    path = Path.join(params.memory_dir, "MEMORY.md")

    content =
      case File.read(path) do
        {:ok, content} -> content
        {:error, _} -> ""
      end

    {:ok, %{content: content}}
  end
end
