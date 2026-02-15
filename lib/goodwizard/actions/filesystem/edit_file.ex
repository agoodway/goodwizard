defmodule Goodwizard.Actions.Filesystem.EditFile do
  @moduledoc """
  Performs find-and-replace on a file's contents.
  """

  use Jido.Action,
    name: "edit_file",
    description: "Find and replace text in a file",
    schema: [
      path: [type: :string, required: true, doc: "Path to the file to edit"],
      old_text: [type: :string, required: true, doc: "Text to find"],
      new_text: [type: :string, required: true, doc: "Text to replace with"]
    ]

  alias Goodwizard.Actions.Filesystem

  @impl true
  def run(params, _context) do
    with {:ok, resolved} <- Filesystem.resolve_path(params.path),
         :ok <- ensure_file_exists(resolved),
         {:ok, content} <- read_file(resolved) do
      do_replace(resolved, content, params.old_text, params.new_text)
    end
  end

  defp ensure_file_exists(path) do
    if File.exists?(path), do: :ok, else: {:error, "File not found: #{path}"}
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, "Failed to read file: #{:file.format_error(reason)}"}
    end
  end

  defp do_replace(path, content, old_text, new_text) do
    case count_occurrences(content, old_text) do
      0 ->
        {:error, "old_text not found in file. Make sure it matches exactly."}

      1 ->
        new_content = String.replace(content, old_text, new_text, global: false)

        case File.write(path, new_content) do
          :ok -> {:ok, %{message: "Successfully edited #{path}"}}
          {:error, reason} -> {:error, "Failed to write file: #{:file.format_error(reason)}"}
        end

      n ->
        {:error, "old_text appears #{n} times. Please provide more context to make it unique."}
    end
  end

  defp count_occurrences(content, pattern) do
    content
    |> String.split(pattern)
    |> length()
    |> Kernel.-(1)
  end
end
