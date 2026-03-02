defmodule Goodwizard.Brain.Paths do
  @moduledoc """
  Safe, workspace-relative path helpers for the knowledge base directory structure.

  All canonical paths are resolved relative to the workspace's `knowledge_base/` directory.
  Rejects path traversal attempts (`..`, leading `/`, null bytes) in
  entity type names and IDs.
  """

  @doc "Returns the canonical knowledge base directory for a workspace."
  @spec knowledge_base_dir(String.t()) :: String.t()
  def knowledge_base_dir(workspace), do: Path.join(workspace, "knowledge_base")

  @doc "Returns the legacy brain directory for a workspace."
  @spec legacy_brain_dir(String.t()) :: String.t()
  def legacy_brain_dir(workspace), do: Path.join(workspace, "brain")

  @doc "Returns the canonical knowledge base directory for a workspace."
  @spec brain_dir(String.t()) :: String.t()
  def brain_dir(workspace), do: knowledge_base_dir(workspace)

  @doc "Returns the `knowledge_base/schemas/` directory."
  @spec schemas_dir(String.t()) :: String.t()
  def schemas_dir(workspace), do: Path.join([workspace, "knowledge_base", "schemas"])

  @doc "Returns the `knowledge_base/<type>/` directory for an entity type."
  @spec entity_type_dir(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def entity_type_dir(workspace, type) do
    with :ok <- validate_segment(type, "entity type") do
      {:ok, Path.join([workspace, "knowledge_base", type])}
    end
  end

  @doc "Returns the `knowledge_base/<type>/<id>.md` file path for an entity."
  @spec entity_path(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def entity_path(workspace, type, id) do
    with :ok <- validate_segment(type, "entity type"),
         :ok <- validate_segment(id, "entity id") do
      {:ok, Path.join([workspace, "knowledge_base", type, "#{id}.md"])}
    end
  end

  @doc "Returns the `knowledge_base/schemas/<type>.json` file path for a schema."
  @spec schema_path(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def schema_path(workspace, type) do
    with :ok <- validate_segment(type, "schema type") do
      {:ok, Path.join([workspace, "knowledge_base", "schemas", "#{type}.json"])}
    end
  end

  @doc """
  Validates that a path segment is safe. Rejects `..`, leading `/`, and null bytes.
  """
  @spec validate_segment(String.t(), String.t()) :: :ok | {:error, String.t()}
  @max_segment_length 255

  def validate_segment(segment, label) do
    cond do
      segment == "" ->
        {:error, "#{label} must not be empty"}

      byte_size(segment) > @max_segment_length ->
        {:error, "#{label} exceeds maximum length of #{@max_segment_length}"}

      String.contains?(segment, "\0") ->
        {:error, "#{label} contains null bytes"}

      String.contains?(segment, "..") ->
        {:error, "#{label} contains path traversal"}

      String.starts_with?(segment, "/") ->
        {:error, "#{label} must be relative"}

      String.contains?(segment, "/") ->
        {:error, "#{label} contains path separator"}

      String.contains?(segment, "\\") ->
        {:error, "#{label} contains path separator"}

      true ->
        :ok
    end
  end
end
