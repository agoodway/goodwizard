defmodule Goodwizard.Brain.Schema do
  @moduledoc """
  Schema loading, validation, and management for the brain knowledge base.

  Uses `ex_json_schema` (draft 7) to resolve and validate entity data
  against JSON Schema definitions stored in `brain/schemas/`.
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
  Writes a schema map to disk as `brain/schemas/<type>.json`.

  When updating an existing schema, enforces `current_version + 1`,
  requires a migration definition, archives the current schema, and
  stores the migration definition before overwriting.
  """
  @spec save(String.t(), String.t(), map()) :: :ok | {:error, term()}
  def save(workspace, type, schema_map), do: save(workspace, type, schema_map, nil)

  @spec save(String.t(), String.t(), map(), map() | nil) :: :ok | {:error, term()}
  def save(workspace, type, schema_map, migration_definition) do
    with {:ok, path} <- Paths.schema_path(workspace, type),
         :ok <- File.mkdir_p(Paths.schemas_dir(workspace)),
         :ok <- prepare_update(path, workspace, type, schema_map, migration_definition),
         {:ok, json} <- Jason.encode(schema_map, pretty: true) do
      File.write(path, json)
    end
  end

  @spec prepare_update(String.t(), String.t(), String.t(), map(), map() | nil) ::
          :ok | {:error, term()}
  defp prepare_update(path, workspace, type, new_schema_map, migration_definition) do
    case File.read(path) do
      {:error, :enoent} ->
        :ok

      {:error, reason} ->
        {:error, reason}

      {:ok, content} ->
        with {:ok, current_schema_map} <- Jason.decode(content),
             {:ok, current_version} <- schema_version(current_schema_map, "current schema"),
             {:ok, new_version} <- schema_version(new_schema_map, "new schema"),
             :ok <- validate_next_version(current_version, new_version),
             :ok <-
               validate_migration_definition(migration_definition, current_version, new_version),
             :ok <- archive_current_schema(workspace, type, current_version, content),
             :ok <-
               store_migration(
                 workspace,
                 type,
                 current_version,
                 new_version,
                 migration_definition
               ) do
          :ok
        end
    end
  end

  @spec schema_version(map(), String.t()) :: {:ok, integer()} | {:error, term()}
  defp schema_version(schema_map, label) do
    case Map.get(schema_map, "version") do
      version when is_integer(version) and version > 0 ->
        {:ok, version}

      _ ->
        {:error, {:invalid_schema_version, label}}
    end
  end

  @spec validate_next_version(integer(), integer()) :: :ok | {:error, term()}
  defp validate_next_version(current_version, new_version) do
    expected = current_version + 1

    if new_version == expected do
      :ok
    else
      {:error, {:version_mismatch, expected, new_version}}
    end
  end

  @spec validate_migration_definition(map() | nil, integer(), integer()) :: :ok | {:error, term()}
  defp validate_migration_definition(nil, _current_version, _new_version),
    do: {:error, :migration_required}

  defp validate_migration_definition(migration_definition, current_version, new_version)
       when is_map(migration_definition) do
    from_version = migration_value(migration_definition, "from_version", :from_version)
    to_version = migration_value(migration_definition, "to_version", :to_version)
    operations = migration_value(migration_definition, "operations", :operations)

    cond do
      not (is_integer(from_version) and from_version > 0) ->
        {:error, {:invalid_migration_definition, :from_version}}

      not (is_integer(to_version) and to_version > 0) ->
        {:error, {:invalid_migration_definition, :to_version}}

      from_version != current_version ->
        {:error, {:migration_version_mismatch, :from_version, current_version, from_version}}

      to_version != new_version ->
        {:error, {:migration_version_mismatch, :to_version, new_version, to_version}}

      not is_list(operations) ->
        {:error, {:invalid_migration_definition, :operations}}

      true ->
        :ok
    end
  end

  defp validate_migration_definition(_migration_definition, _current_version, _new_version),
    do: {:error, {:invalid_migration_definition, :format}}

  @spec archive_current_schema(String.t(), String.t(), integer(), String.t()) ::
          :ok | {:error, term()}
  defp archive_current_schema(workspace, type, current_version, content) do
    with {:ok, history_path} <- Paths.schema_history_path(workspace, type, current_version),
         :ok <- File.mkdir_p(Paths.schema_history_dir(workspace)) do
      File.write(history_path, content)
    end
  end

  @spec store_migration(String.t(), String.t(), integer(), integer(), map()) ::
          :ok | {:error, term()}
  defp store_migration(workspace, type, from_version, to_version, migration_definition) do
    with {:ok, path} <- Paths.migration_path(workspace, type, from_version, to_version),
         :ok <- File.mkdir_p(Paths.schema_migrations_dir(workspace)),
         {:ok, json} <- Jason.encode(migration_definition, pretty: true) do
      File.write(path, json)
    end
  end

  @spec migration_value(map(), String.t(), atom()) :: term()
  defp migration_value(migration_definition, string_key, atom_key) do
    Map.get(migration_definition, string_key) || Map.get(migration_definition, atom_key)
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
