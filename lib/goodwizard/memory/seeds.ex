defmodule Goodwizard.Memory.Seeds do
  @moduledoc """
  Bootstrap the memory directory structure within a workspace.

  Creates `memory/episodic/` and `memory/procedural/` subdirectories and
  ensures `memory/MEMORY.md` exists. Idempotent — safe to call multiple
  times without errors or data loss.
  """

  @doc """
  Seeds the memory directory structure under `workspace`.

  Creates:
  - `memory/episodic/`
  - `memory/procedural/`
  - `memory/MEMORY.md` (only if the file does not already exist)

  Returns `:ok` on success. Raises on filesystem failures since seeding
  runs at setup time, not in the agent hot loop.
  """
  @spec seed(String.t()) :: :ok
  def seed(workspace) do
    memory_dir = Path.join(workspace, "memory")

    File.mkdir_p!(Path.join(memory_dir, "episodic"))
    File.mkdir_p!(Path.join(memory_dir, "procedural"))

    memory_md = Path.join(memory_dir, "MEMORY.md")

    unless File.exists?(memory_md) do
      File.write!(memory_md, "")
    end

    :ok
  end
end
