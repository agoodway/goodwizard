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

  alias Goodwizard.Memory.Paths

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, _context) do
    with {:ok, _} <- Paths.validate_memory_dir(params.memory_dir) do
      path = Paths.memory_path(params.memory_dir)

      content =
        case File.read(path) do
          {:ok, content} -> content
          {:error, _} -> ""
        end

      {:ok, %{content: content}}
    end
  end
end
