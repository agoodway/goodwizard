defmodule Goodwizard.Actions.Filesystem do
  @moduledoc """
  Shared utilities for filesystem actions.
  """

  @doc """
  Resolves a path with tilde expansion and optional allowed_dir enforcement.

  Returns `{:ok, expanded_path}` or `{:error, reason}`.
  """
  @spec resolve_path(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def resolve_path(path), do: resolve_path(path, nil)

  @doc false
  @spec resolve_path(String.t(), String.t() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def resolve_path(path, allowed_dir) do
    expanded = Path.expand(path)
    effective_dir = allowed_dir || default_allowed_dir()

    case effective_dir do
      nil ->
        {:ok, expanded}

      dir ->
        expanded_dir = Path.expand(dir)
        real_path = resolve_symlinks(expanded)
        real_dir = resolve_symlinks(expanded_dir)

        if String.starts_with?(real_path, real_dir <> "/") or real_path == real_dir do
          {:ok, expanded}
        else
          {:error, "Path #{expanded} is outside allowed directory #{expanded_dir}"}
        end
    end
  end

  defp default_allowed_dir do
    restrict? =
      Application.get_env(:goodwizard, :restrict_to_workspace, :from_config)

    case restrict? do
      false ->
        nil

      _ ->
        if Goodwizard.Config.get(["tools", "restrict_to_workspace"]) do
          Goodwizard.Config.workspace()
        else
          nil
        end
    end
  rescue
    # Config server may not be running (e.g., in tests)
    _ -> nil
  end

  defp resolve_symlinks(path) do
    case :file.read_link_all(path) do
      {:ok, target} ->
        target
        |> List.to_string()
        |> Path.expand(Path.dirname(path))
        |> resolve_symlinks()

      {:error, _} ->
        # Not a symlink or doesn't exist yet — walk parent chain
        parent = Path.dirname(path)

        if parent == path do
          path
        else
          Path.join(resolve_symlinks(parent), Path.basename(path))
        end
    end
  end
end
