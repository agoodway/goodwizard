defmodule Goodwizard.Memory.Seeds do
  @moduledoc """
  Bootstrap the memory directory structure within a workspace.

  Creates `memory/episodic/` and `memory/procedural/` subdirectories and
  ensures `memory/MEMORY.md` exists. Idempotent — safe to call multiple
  times without errors or data loss.
  """

  alias Goodwizard.Memory.Paths

  @subdirs [:episodic, :procedural]

  @doc """
  Seeds the memory directory structure under `workspace`.

  Creates:
  - `memory/episodic/`
  - `memory/procedural/`
  - `memory/MEMORY.md` (only if the file does not already exist)

  Returns `{:ok, created}` where `created` is a list of items that were
  newly created (e.g. `["episodic", "procedural", "MEMORY.md"]`).
  Returns `{:error, term}` on filesystem failures.
  """
  @spec seed(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def seed(workspace) do
    memory_dir = Path.join(workspace, "memory")

    with {:ok, dir_created} <- create_subdirs(memory_dir),
         {:ok, file_created} <- create_memory_md(memory_dir) do
      {:ok, dir_created ++ file_created}
    end
  end

  defp create_subdirs(memory_dir) do
    Enum.reduce_while(@subdirs, {:ok, []}, fn subdir, {:ok, created} ->
      dir = apply(Paths, :"#{subdir}_dir", [memory_dir])

      case File.mkdir_p(dir) do
        :ok -> {:cont, {:ok, created ++ [to_string(subdir)]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp create_memory_md(memory_dir) do
    path = Paths.memory_path(memory_dir)

    case File.open(path, [:write, :exclusive]) do
      {:ok, file} ->
        File.close(file)
        {:ok, ["MEMORY.md"]}

      {:error, :eexist} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
