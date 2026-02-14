defmodule Goodwizard.Actions.Filesystem.ReadFile do
  @moduledoc """
  Reads the contents of a file at the given path.
  """

  @default_max_file_size 10_000_000

  use Jido.Action,
    name: "read_file",
    description: "Read the contents of a file",
    schema: [
      path: [type: :string, required: true, doc: "Path to the file to read"],
      allowed_dir: [type: :string, doc: "Optional directory constraint"],
      max_file_size: [type: :integer, default: 10_000_000, doc: "Maximum file size in bytes"]
    ]

  alias Goodwizard.Actions.Filesystem

  @impl true
  def run(params, _context) do
    max_size = Map.get(params, :max_file_size, @default_max_file_size)

    with {:ok, resolved} <- Filesystem.resolve_path(params.path, Map.get(params, :allowed_dir)),
         :ok <- check_file_exists(resolved),
         :ok <- check_file_size(resolved, max_size) do
      case File.read(resolved) do
        {:ok, content} -> {:ok, %{content: content}}
        {:error, reason} -> {:error, "Failed to read file: #{:file.format_error(reason)}"}
      end
    end
  end

  defp check_file_exists(path) do
    cond do
      not File.exists?(path) -> {:error, "File not found: #{path}"}
      File.dir?(path) -> {:error, "Not a file: #{path}"}
      true -> :ok
    end
  end

  defp check_file_size(path, max_size) do
    case File.stat(path) do
      {:ok, %{size: size}} when size > max_size ->
        {:error, "File too large: #{size} bytes exceeds limit of #{max_size} bytes"}

      _ ->
        :ok
    end
  end
end
