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
  Ensures the memory directory exists, after validating the path.

  Validates via `validate_memory_dir/1` before creating. Returns `:ok` or
  `{:error, reason}`.
  """
  @spec ensure_dir(String.t()) :: :ok | {:error, term()}
  def ensure_dir(memory_dir) do
    with {:ok, expanded} <- validate_memory_dir(memory_dir) do
      File.mkdir_p(expanded)
    end
  end

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

  Validates the ID to prevent path traversal. Returns `{:ok, path}` or
  `{:error, :invalid_id}`.
  """
  @spec episode_path(String.t(), String.t()) :: {:ok, String.t()} | {:error, :invalid_id}
  def episode_path(memory_dir, id) do
    with :ok <- validate_id(id) do
      {:ok, Path.join(episodic_dir(memory_dir), "#{id}.md")}
    end
  end

  @doc """
  Returns the path to a specific procedure entry file by ID.

  Validates the ID to prevent path traversal. Returns `{:ok, path}` or
  `{:error, :invalid_id}`.
  """
  @spec procedure_path(String.t(), String.t()) :: {:ok, String.t()} | {:error, :invalid_id}
  def procedure_path(memory_dir, id) do
    with :ok <- validate_id(id) do
      {:ok, Path.join(procedural_dir(memory_dir), "#{id}.md")}
    end
  end

  @doc """
  Validates an entry ID. Rejects IDs containing `..`, `/`, `\\`, null bytes,
  or empty strings.
  """
  @spec validate_id(String.t()) :: :ok | {:error, :invalid_id}
  def validate_id(id) when is_binary(id) and byte_size(id) > 0 do
    if String.contains?(id, ["..", "/", "\\", "\0"]) do
      {:error, :invalid_id}
    else
      :ok
    end
  end

  def validate_id(_), do: {:error, :invalid_id}

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

  # 4096 bytes — common filesystem path length limit
  @max_path_length 4096

  @doc """
  Validates that the given memory_dir is a safe path without traversal components.
  Rejects empty strings, paths with `..` as a path component, null bytes,
  non-printable characters, and paths exceeding #{@max_path_length} bytes.
  Returns {:ok, expanded_path} or {:error, reason}.
  """
  @spec validate_memory_dir(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_memory_dir(""), do: {:error, "memory_dir is empty"}

  def validate_memory_dir(memory_dir) do
    cond do
      byte_size(memory_dir) > @max_path_length ->
        {:error, "memory_dir exceeds maximum path length"}

      String.contains?(memory_dir, "\0") ->
        {:error, "memory_dir contains null bytes"}

      has_traversal_component?(memory_dir) ->
        {:error, "memory_dir contains path traversal"}

      not String.printable?(memory_dir) ->
        {:error, "memory_dir contains non-printable characters"}

      true ->
        {:ok, Path.expand(memory_dir)}
    end
  end

  # Checks for ".." as an actual path component, not as a substring.
  # "/tmp/app..v2/data" is valid; "/tmp/../etc" is not.
  defp has_traversal_component?(path) do
    path
    |> Path.split()
    |> Enum.any?(&(&1 == ".."))
  end
end
