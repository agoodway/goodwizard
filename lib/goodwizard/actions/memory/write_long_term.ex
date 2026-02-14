defmodule Goodwizard.Actions.Memory.WriteLongTerm do
  @moduledoc """
  Writes content to MEMORY.md, replacing existing content.
  """

  use Jido.Action,
    name: "write_long_term",
    description: "Write content to the agent's long-term memory (MEMORY.md)",
    schema: [
      memory_dir: [type: :string, required: true, doc: "Path to the memory directory"],
      content: [type: :string, required: true, doc: "Content to write to MEMORY.md"]
    ]

  @impl true
  def run(params, _context) do
    path = Path.join(params.memory_dir, "MEMORY.md")

    case File.mkdir_p(params.memory_dir) do
      :ok ->
        case File.write(path, params.content) do
          :ok ->
            {:ok, %{message: "Successfully wrote #{byte_size(params.content)} bytes to MEMORY.md"}}

          {:error, reason} ->
            {:error, "Failed to write MEMORY.md: #{:file.format_error(reason)}"}
        end

      {:error, reason} ->
        {:error, "Failed to create memory directory: #{:file.format_error(reason)}"}
    end
  end
end
