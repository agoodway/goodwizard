defmodule Goodwizard.Actions.Filesystem.WriteFile do
  @moduledoc """
  Creates or overwrites a file with the given content.
  """

  use Jido.Action,
    name: "write_file",
    description: "Write content to a file, creating parent directories if needed",
    schema: [
      path: [type: :string, required: true, doc: "Path to the file to write"],
      content: [type: :string, required: true, doc: "Content to write to the file"]
    ]

  alias Goodwizard.Actions.Filesystem

  @impl true
  def run(params, _context) do
    with {:ok, resolved} <- Filesystem.resolve_path(params.path),
         :ok <- resolved |> Path.dirname() |> File.mkdir_p() do
      case File.write(resolved, params.content) do
        :ok ->
          bytes = byte_size(params.content)
          {:ok, %{message: "Successfully wrote #{bytes} bytes to #{resolved}"}}

        {:error, reason} ->
          {:error, "Failed to write file: #{:file.format_error(reason)}"}
      end
    else
      {:error, reason} when is_atom(reason) ->
        {:error, "Failed to create directory: #{:file.format_error(reason)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
