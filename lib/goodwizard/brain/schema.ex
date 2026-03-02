defmodule Goodwizard.Brain.Schema do
  @moduledoc """
  Schema loading, validation, and management for the knowledge base subsystem.

  Uses `ex_json_schema` (draft 7) to resolve and validate entity data
  against JSON Schema definitions stored in `knowledge_base/schemas/`.
  """

  alias Goodwizard.Brain.Paths

  @doc """
  Loads and resolves a JSON Schema from disk for the given entity type.

  Returns `{:ok, resolved_schema}` or `{:error, reason}`.
  """
  @spec load(String.t(), String.t()) :: {:ok, ExJsonSchema.Schema.Root.t()} | {:error, term()}
  def load(workspace, type) do
    with {:ok, path} <- Paths.schema_path(workspace, type),
         {:ok, content} <- File.read(path),
         {:ok, schema_map} <- Jason.decode(content) do
      try do
        {:ok, ExJsonSchema.Schema.resolve(schema_map)}
      rescue
        e in [
          ExJsonSchema.Schema.InvalidSchemaError,
          ExJsonSchema.Schema.UnsupportedSchemaVersionError,
          ExJsonSchema.Schema.InvalidReferenceError,
          ExJsonSchema.Schema.UndefinedRemoteSchemaResolverError
        ] ->
          {:error, {:schema_resolution_error, Exception.message(e)}}
      end
    end
  end

  @doc """
  Validates data against a resolved schema.

  Returns `:ok` or `{:error, errors}` where errors is a list of
  `{message, path}` tuples.
  """
  @spec validate(ExJsonSchema.Schema.Root.t(), map()) ::
          :ok | {:error, [{String.t(), String.t()}]}
  def validate(resolved_schema, data) do
    ExJsonSchema.Validator.validate(resolved_schema, data)
  end

  @doc """
  Writes a schema map to disk as `knowledge_base/schemas/<type>.json`.

  Creates the schemas directory if it doesn't exist.
  Returns `:ok` or `{:error, reason}`.
  """
  @spec save(String.t(), String.t(), map()) :: :ok | {:error, term()}
  def save(workspace, type, schema_map) do
    with {:ok, path} <- Paths.schema_path(workspace, type),
         :ok <- File.mkdir_p(Paths.schemas_dir(workspace)),
         {:ok, json} <- Jason.encode(schema_map, pretty: true) do
      File.write(path, json)
    end
  end

  @system_fields ~w(id created_at updated_at)

  @doc """
  Returns summaries of all entity types with their required and optional fields.

  Each summary is a map with `:type`, `:title`, `:required`, and `:optional` keys.
  System fields (id, created_at, updated_at) are excluded from the field lists.
  Skips schemas that cannot be read or decoded.

  Returns `{:ok, [summary]}` or `{:error, reason}`.
  """
  @spec summarize_types(String.t()) :: {:ok, [map()]} | {:error, term()}
  def summarize_types(workspace) do
    case list_types(workspace) do
      {:ok, types} ->
        summaries =
          types
          |> Enum.map(&summarize_type(workspace, &1))
          |> Enum.reject(&is_nil/1)

        {:ok, summaries}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp summarize_type(workspace, type) do
    with {:ok, path} <- Paths.schema_path(workspace, type),
         {:ok, content} <- File.read(path),
         {:ok, schema_map} <- Jason.decode(content) do
      all_required = Map.get(schema_map, "required", [])
      properties = Map.get(schema_map, "properties", %{}) |> Map.keys()

      required = Enum.reject(all_required, &(&1 in @system_fields))
      optional = (properties -- all_required) |> Enum.reject(&(&1 in @system_fields))

      %{
        type: type,
        title: Map.get(schema_map, "title", type),
        required: Enum.sort(required),
        optional: Enum.sort(optional)
      }
    else
      _ -> nil
    end
  end

  @doc """
  Lists available entity types by scanning the schemas directory.

  Returns `{:ok, [type_name]}` where type names are derived from
  `.json` filenames (without extension).
  """
  @spec list_types(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def list_types(workspace) do
    schemas_dir = Paths.schemas_dir(workspace)

    case File.ls(schemas_dir) do
      {:ok, files} ->
        types =
          files
          |> Enum.filter(&String.ends_with?(&1, ".json"))
          |> Enum.map(&String.replace_suffix(&1, ".json", ""))
          |> Enum.sort()

        {:ok, types}

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
