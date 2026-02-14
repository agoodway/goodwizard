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

    with :ok <- check_content_size(content_size),
         {:ok, _} <- Paths.validate_memory_dir(params.memory_dir),
         :ok <- Paths.ensure_dir(params.memory_dir) do
      write_memory_file(params.memory_dir, params.content, content_size)
    else
      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, reason} ->
        {:error, "Failed to create memory directory: #{:file.format_error(reason)}"}
    end
  end

  defp check_content_size(size) when size > @max_content_size do
    {:error, "Content exceeds maximum size of #{@max_content_size} bytes (got #{size})"}
  end

  defp check_content_size(_size), do: :ok

  defp write_memory_file(memory_dir, content, content_size) do
    path = Paths.memory_path(memory_dir)

    case File.write(path, content) do
      :ok ->
        File.chmod(path, 0o600)
        {:ok, %{message: "Successfully wrote #{content_size} bytes to MEMORY.md"}}

      {:error, reason} ->
        {:error, "Failed to write MEMORY.md: #{:file.format_error(reason)}"}
    end
  end
end
