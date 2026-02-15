defmodule Goodwizard.Brain do
  @moduledoc """
  Entry point for the brain knowledge base subsystem.

  Provides CRUD operations for entities stored as markdown files with
  YAML frontmatter, validated against JSON Schema definitions.
  """

  alias Goodwizard.Brain.{Entity, Id, Paths, Schema, Seeds}

  @system_fields ["id", "created_at", "updated_at"]
  @max_list_entities 1_000
  # 10 MB max body size
  @max_body_bytes 10_485_760

  @doc """
  Creates a new entity of the given type.

  Generates an ID, sets timestamps, validates against the type's schema,
  and writes the entity file. Initializes the brain on first use.

  Returns `{:ok, {id, data, body}}` or `{:error, reason}`.
  """
  @spec create(String.t(), String.t(), map(), String.t()) ::
          {:ok, {String.t(), map(), String.t()}} | {:error, term()}
  def create(workspace, entity_type, data, body \\ "") do
    if byte_size(body) > @max_body_bytes do
      {:error, :body_too_large}
    else
      do_create(workspace, entity_type, data, body)
    end
  end

  defp do_create(workspace, entity_type, data, body) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    with {:ok, _} <- ensure_initialized(workspace),
         {:ok, id} <- Id.generate(workspace),
         data = data |> Map.drop(@system_fields) |> Map.merge(%{"id" => id, "created_at" => now, "updated_at" => now}),
         {:ok, schema} <- Schema.load(workspace, entity_type),
         :ok <- Schema.validate(schema, data),
         {:ok, type_dir} <- Paths.entity_type_dir(workspace, entity_type),
         :ok <- File.mkdir_p(type_dir),
         {:ok, path} <- Paths.entity_path(workspace, entity_type, id) do
      content = Entity.serialize(data, body)

      case write_exclusive(path, content, id) do
        :ok -> {:ok, {id, data, body}}
        {:error, _} = error -> error
      end
    end
  end

  @doc """
  Reads an entity by type and ID.

  Returns `{:ok, {data, body}}` or `{:error, reason}`.
  """
  @spec read(String.t(), String.t(), String.t()) ::
          {:ok, {map(), String.t()}} | {:error, term()}
  def read(workspace, entity_type, id) do
    with {:ok, path} <- Paths.entity_path(workspace, entity_type, id),
         {:ok, content} <- safe_read(path, workspace) do
      Entity.parse(content)
    end
  end

  @doc """
  Updates an existing entity. Merges new data with existing data,
  updates the `updated_at` timestamp, validates, and writes.

  If `body` is nil, the existing body is preserved.
  Returns `{:ok, {data, body}}` or `{:error, reason}`.
  """
  @spec update(String.t(), String.t(), String.t(), map(), String.t() | nil) ::
          {:ok, {map(), String.t()}} | {:error, term()}
  def update(workspace, entity_type, id, new_data, body \\ nil) do
    if body != nil and byte_size(body) > @max_body_bytes do
      {:error, :body_too_large}
    else
      do_update(workspace, entity_type, id, new_data, body)
    end
  end

  defp do_update(workspace, entity_type, id, new_data, body) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    with {:ok, path} <- Paths.entity_path(workspace, entity_type, id),
         {:ok, real_path} <- safe_resolve(path, workspace),
         {:ok, schema} <- Schema.load(workspace, entity_type) do
      locked_update(real_path, now, new_data, body, schema)
    end
  end

  defp locked_update(path, now, new_data, body, schema) do
    lock_file = path <> ".lock"

    case :file.open(lock_file, [:write, :exclusive]) do
      {:ok, lock_fd} ->
        try do
          with {:ok, content} <- read_file(path),
               {:ok, {existing_data, existing_body}} <- Entity.parse(content),
               safe_data = Map.drop(new_data, ["id", "created_at", "updated_at"]),
               merged = Map.merge(existing_data, safe_data) |> Map.put("updated_at", now),
               final_body = if(body != nil, do: body, else: existing_body),
               :ok <- Schema.validate(schema, merged) do
            result = Entity.serialize(merged, final_body)

            case File.write(path, result) do
              :ok -> {:ok, {merged, final_body}}
              {:error, reason} -> {:error, reason}
            end
          end
        after
          :file.close(lock_fd)
          File.rm(lock_file)
        end

      {:error, :eexist} ->
        {:error, :update_locked}

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes an entity by type and ID.

  Returns `:ok` or `{:error, reason}`.
  """
  @spec delete(String.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def delete(workspace, entity_type, id) do
    with {:ok, path} <- Paths.entity_path(workspace, entity_type, id),
         {:ok, real_path} <- safe_resolve(path, workspace) do
      case File.rm(real_path) do
        :ok -> :ok
        {:error, :enoent} -> {:error, :not_found}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Lists all entities of a given type.

  Initializes the brain on first use. Returns `{:ok, [{data, body}]}`
  or `{:error, reason}`.
  """
  @spec list(String.t(), String.t()) ::
          {:ok, [{map(), String.t()}]} | {:error, term()}
  def list(workspace, entity_type) do
    with {:ok, _} <- ensure_initialized(workspace),
         {:ok, type_dir} <- Paths.entity_type_dir(workspace, entity_type) do
      case File.ls(type_dir) do
        {:ok, files} ->
          files
          |> Enum.filter(&String.ends_with?(&1, ".md"))
          |> Enum.sort()
          |> Enum.take(@max_list_entities)
          |> Enum.reduce_while({:ok, []}, fn file, {:ok, acc} ->
            path = Path.join(type_dir, file)

            case safe_read(path, workspace) do
              {:ok, content} ->
                case Entity.parse(content) do
                  {:ok, entity} -> {:cont, {:ok, [entity | acc]}}
                  {:error, reason} -> {:halt, {:error, {:parse_error, file, reason}}}
                end

              {:error, reason} ->
                {:halt, {:error, reason}}
            end
          end)
          |> case do
            {:ok, entities} -> {:ok, Enum.reverse(entities)}
            error -> error
          end

        {:error, :enoent} ->
          {:ok, []}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Ensures the brain directory structure exists and seeds default schemas
  if the schemas directory is empty.

  Safe to call multiple times — only seeds on first use.
  Returns `{:ok, seeded_types}` where `seeded_types` is the list of
  newly created schema types (empty list if already seeded).
  """
  @spec ensure_initialized(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def ensure_initialized(workspace) do
    brain_dir = Paths.brain_dir(workspace)
    schemas_dir = Paths.schemas_dir(workspace)

    with :ok <- File.mkdir_p(brain_dir),
         :ok <- File.mkdir_p(schemas_dir),
         {:ok, existing} <- Schema.list_types(workspace) do
      if existing == [] do
        Seeds.seed(workspace)
      else
        {:ok, []}
      end
    end
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, :enoent} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp safe_resolve(path, workspace) do
    real_path = resolve_symlinks(path)
    real_workspace = resolve_symlinks(Path.expand(workspace))

    if String.starts_with?(real_path, real_workspace <> "/") do
      {:ok, real_path}
    else
      {:error, :path_traversal}
    end
  end

  defp safe_read(path, workspace) do
    with {:ok, real_path} <- safe_resolve(path, workspace) do
      read_file(real_path)
    end
  end

  @max_symlink_depth 40

  defp resolve_symlinks(path, depth \\ 0)

  defp resolve_symlinks(path, depth) when depth >= @max_symlink_depth, do: path

  defp resolve_symlinks(path, depth) do
    case :file.read_link_all(path) do
      {:ok, target} ->
        target
        |> List.to_string()
        |> Path.expand(Path.dirname(path))
        |> resolve_symlinks(depth + 1)

      {:error, _} ->
        parent = Path.dirname(path)

        if parent == path do
          path
        else
          Path.join(resolve_symlinks(parent, depth + 1), Path.basename(path))
        end
    end
  end

  defp write_exclusive(path, content, id) do
    case :file.open(path, [:write, :exclusive]) do
      {:ok, fd} ->
        try do
          :file.write(fd, content)
        after
          :file.close(fd)
        end

      {:error, :eexist} ->
        {:error, {:duplicate_id, id}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
