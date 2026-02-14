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
