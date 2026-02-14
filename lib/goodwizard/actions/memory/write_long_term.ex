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

  alias Goodwizard.Memory.Paths

  # 100 KB max memory content size
  @max_content_size 100 * 1024

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, _context) do
    content_size = byte_size(params.content)

    if content_size > @max_content_size do
      {:error, "Content exceeds maximum size of #{@max_content_size} bytes (got #{content_size})"}
    else
      with {:ok, _} <- Paths.validate_memory_dir(params.memory_dir),
           :ok <- Paths.ensure_dir(params.memory_dir) do
        path = Paths.memory_path(params.memory_dir)

        case File.write(path, params.content) do
          :ok ->
            File.chmod(path, 0o600)
            {:ok, %{message: "Successfully wrote #{content_size} bytes to MEMORY.md"}}

          {:error, reason} ->
            {:error, "Failed to write MEMORY.md: #{:file.format_error(reason)}"}
        end
      else
        {:error, reason} when is_binary(reason) ->
          {:error, reason}

        {:error, reason} ->
          {:error, "Failed to create memory directory: #{:file.format_error(reason)}"}
      end
    end
  end
end
