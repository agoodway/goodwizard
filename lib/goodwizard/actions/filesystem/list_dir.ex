defmodule Goodwizard.Actions.Filesystem.ListDir do
  @moduledoc """
  Lists directory entries with [DIR] and [FILE] prefixes.
  """

  use Jido.Action,
    name: "list_dir",
    description: "List files and directories in a directory",
    schema: [
      path: [type: :string, required: true, doc: "Path to the directory to list"]
    ]

  alias Goodwizard.Actions.Filesystem

  @impl true
  def run(params, _context) do
    with {:ok, resolved} <- Filesystem.resolve_path(params.path),
         :ok <- check_directory(resolved) do
      case File.ls(resolved) do
        {:ok, entries} ->
          format_entries(resolved, Enum.sort(entries))

        {:error, reason} ->
          {:error, "Failed to list directory: #{:file.format_error(reason)}"}
      end
    end
  end

  defp check_directory(path) do
    cond do
      not File.exists?(path) -> {:error, "Directory not found: #{path}"}
      not File.dir?(path) -> {:error, "Not a directory: #{path}"}
      true -> :ok
    end
  end

  defp format_entries(path, []) do
    {:ok, %{entries: "Directory #{path} is empty"}}
  end

  defp format_entries(path, entries) do
    listing =
      Enum.map_join(entries, "\n", fn entry ->
        full_path = Path.join(path, entry)
        prefix = if File.dir?(full_path), do: "[DIR]", else: "[FILE]"
        "#{prefix} #{entry}"
      end)

    {:ok, %{entries: listing}}
  end
end
