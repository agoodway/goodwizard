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
      {:ok, ExJsonSchema.Schema.resolve(schema_map)}
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
