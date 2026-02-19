defmodule Goodwizard.Actions.Memory.AppendHistory do
  @moduledoc """
  Appends a timestamped entry to HISTORY.md.
  """

  use Jido.Action,
    name: "append_history",
    description: "Append a timestamped entry to conversation history (HISTORY.md)",
    schema: [
      memory_dir: [type: :string, required: true, doc: "Path to the memory directory"],
      entry: [type: :string, required: true, doc: "Entry text to append"]
    ]

  alias Goodwizard.Memory.Paths

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, _context) do
    with {:ok, _} <- Paths.validate_memory_dir(params.memory_dir),
         :ok <- Paths.ensure_dir(params.memory_dir) do
      path = Paths.history_path(params.memory_dir)
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
      line = "[#{timestamp}] #{params.entry}\n"

      case File.write(path, line, [:append]) do
        :ok ->
          File.chmod(path, 0o600)
          {:ok, %{message: "Appended entry to HISTORY.md"}}

        {:error, reason} ->
          {:error, "Failed to append to HISTORY.md: #{:file.format_error(reason)}"}
      end
    else
      {:error, :path_traversal} ->
        {:error, "memory_dir path traversal is not allowed"}

      {:error, reason} ->
        {:error, "Failed to create memory directory: #{:file.format_error(reason)}"}
    end
  end
end
