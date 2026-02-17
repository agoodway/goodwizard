defmodule Goodwizard.Memory.Paths do
  @moduledoc """
  Shared file path helpers for memory actions.

  Centralizes path construction, directory creation, and path validation
  to prevent path traversal attacks.
  """

  @doc """
  Returns the path to HISTORY.md within the given memory directory.
  """
  @spec history_path(String.t()) :: String.t()
  def history_path(memory_dir), do: Path.join(memory_dir, "HISTORY.md")

  @doc """
  Returns the path to MEMORY.md within the given memory directory.
  """
  @spec memory_path(String.t()) :: String.t()
  def memory_path(memory_dir), do: Path.join(memory_dir, "MEMORY.md")

  @doc """
  Ensures the memory directory exists.
  """
  @spec ensure_dir(String.t()) :: :ok | {:error, term()}
  def ensure_dir(memory_dir), do: File.mkdir_p(memory_dir)

  @doc """
  Returns the path to the episodic memory subdirectory.
  """
  @spec episodic_dir(String.t()) :: String.t()
  def episodic_dir(memory_dir), do: Path.join(memory_dir, "episodic")

  @doc """
  Returns the path to the procedural memory subdirectory.
  """
  @spec procedural_dir(String.t()) :: String.t()
  def procedural_dir(memory_dir), do: Path.join(memory_dir, "procedural")

  @doc """
  Returns the path to a specific episode entry file by ID.
  """
  @spec episode_path(String.t(), String.t()) :: String.t()
  def episode_path(memory_dir, id), do: Path.join(episodic_dir(memory_dir), "#{id}.md")

  @doc """
  Returns the path to a specific procedure entry file by ID.
  """
  @spec procedure_path(String.t(), String.t()) :: String.t()
  def procedure_path(memory_dir, id), do: Path.join(procedural_dir(memory_dir), "#{id}.md")

  @valid_subdirs ~w(episodic procedural)

  @doc """
  Validates that the subdirectory name is in the allowed set and returns the full path.

  Returns `{:ok, path}` for valid names (`episodic`, `procedural`),
  or `{:error, :invalid_subdir}` for anything else.
  """
  @spec validate_memory_subdir(String.t(), String.t()) ::
          {:ok, String.t()} | {:error, :invalid_subdir}
  def validate_memory_subdir(memory_dir, subdir) when subdir in @valid_subdirs do
    {:ok, Path.join(memory_dir, subdir)}
  end

  def validate_memory_subdir(_memory_dir, _subdir), do: {:error, :invalid_subdir}

  @doc """
  Validates that the given memory_dir is a safe path without traversal components.
  Rejects paths containing `..`, null bytes, or non-printable characters.
  Returns {:ok, expanded_path} or {:error, reason}.
  """
  @spec validate_memory_dir(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_memory_dir(memory_dir) do
    cond do
      String.contains?(memory_dir, "\0") ->
        {:error, "memory_dir contains null bytes"}

      String.contains?(memory_dir, "..") ->
        {:error, "memory_dir contains path traversal"}

      not String.printable?(memory_dir) ->
        {:error, "memory_dir contains non-printable characters"}

      true ->
        {:ok, Path.expand(memory_dir)}
    end
  end
end
