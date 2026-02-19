defmodule Goodwizard.Brain do
  @moduledoc """
  Entry point for the brain knowledge base subsystem.

  Provides CRUD operations for entities stored as markdown files with
  YAML frontmatter, validated against JSON Schema definitions.
  """

  require Logger

  alias Goodwizard.Brain.{Entity, Id, Migration, Paths, References, Schema, Seeds}

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
         {:ok, id} <- Id.generate(),
         data =
           data
           |> Map.drop(@system_fields)
           |> Map.merge(%{"id" => id, "created_at" => now, "updated_at" => now})
           |> Map.put_new("metadata", %{}),
         {:ok, schema} <- Schema.load(workspace, entity_type),
         :ok <- Schema.validate(schema, data),
         {:ok, type_dir} <- Paths.entity_type_dir(workspace, entity_type),
         :ok <- File.mkdir_p(type_dir),
         {:ok, path} <- Paths.entity_path(workspace, entity_type, id),
         :ok <- write_and_log(path, Entity.serialize(data, body), entity_type, id) do
      {:ok, {id, data, body}}
    end
  end

  defp write_and_log(path, content, entity_type, id) do
    case write_exclusive(path, content, id) do
      :ok ->
        Logger.info("[Brain] wrote entity type=#{entity_type} id=#{id}")
        :ok

      {:error, _} = error ->
        Logger.error(fn ->
          "[Brain] write_exclusive failed type=#{entity_type} id=#{id} error=#{inspect(error)}"
        end)

        error
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
         {:ok, content} <- safe_read(path, workspace),
         {:ok, {data, body}} <- Entity.parse(content) do
      case Schema.load(workspace, entity_type) do
        {:ok, schema} ->
          {:ok, {References.clean_data(workspace, schema, data), body}}

        {:error, reason} ->
          Logger.warning(
            "[Brain] read: failed to load schema for #{entity_type}/#{id}, returning uncleaned data: #{inspect(reason)}"
          )

          {:ok, {data, body}}
      end
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
               existing_data = Map.put_new(existing_data, "metadata", %{}),
               safe_data =
                 new_data
                 |> Map.drop(["id", "created_at", "updated_at"])
                 |> sanitize_metadata(),
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

  # Sanitizes metadata in update data:
  # - absent key: drop it so existing metadata is preserved via Map.merge
  # - nil value: same as absent — treat as "no change"
  # - map value: keep it to replace existing metadata
  defp sanitize_metadata(data) do
    case Map.fetch(data, "metadata") do
      :error -> data
      {:ok, nil} -> Map.delete(data, "metadata")
      {:ok, val} when is_map(val) -> data
      {:ok, _} -> Map.delete(data, "metadata")
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
        :ok ->
          start_sweep_stale_task(workspace, entity_type, id)

          :ok

        {:error, :enoent} ->
          {:error, :not_found}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp start_sweep_stale_task(workspace, entity_type, id) do
    Task.start(fn ->
      try do
        References.sweep_stale(workspace, entity_type, id)
      rescue
        e ->
          Logger.warning(
            "[Brain] sweep_stale crashed for #{entity_type}/#{id}: #{Exception.message(e)}"
          )
      end
    end)
  end

  @doc """
  Migrates entities for a type from one schema version to the next.

  Loads the migration definition and executes it, or performs a dry-run
  when `dry_run` is true.
  """
  @spec migrate(String.t(), String.t(), integer(), integer(), boolean()) ::
          {:ok, map()} | {:error, term()}
  def migrate(workspace, entity_type, from_version, to_version, dry_run \\ false) do
    with {:ok, migration_definition} <-
           Migration.load(workspace, entity_type, from_version, to_version) do
      if dry_run do
        Migration.dry_run(workspace, entity_type, migration_definition)
      else
        Migration.execute(workspace, entity_type, migration_definition)
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
         {:ok, type_dir} <- Paths.entity_type_dir(workspace, entity_type),
         {:ok, files} <- list_entity_files(type_dir),
         {:ok, entities} <- read_entity_files(type_dir, files, workspace) do
      case Schema.load(workspace, entity_type) do
        {:ok, schema} ->
          refs = References.ref_fields(schema)

          {:ok,
           Enum.map(entities, fn {data, body} ->
             {References.clean_data_with_refs(workspace, refs, data), body}
           end)}

        {:error, reason} ->
          Logger.warning(
            "[Brain] list: failed to load schema for #{entity_type}, returning uncleaned data: #{inspect(reason)}"
          )

          {:ok, entities}
      end
    end
  end

  defp list_entity_files(type_dir) do
    case File.ls(type_dir) do
      {:ok, files} ->
        entity_files =
          files
          |> Enum.filter(&String.ends_with?(&1, ".md"))
          |> Enum.sort()
          |> Enum.take(@max_list_entities)

        {:ok, entity_files}

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp read_entity_files(type_dir, files, workspace) do
    files
    |> Enum.reduce_while({:ok, []}, fn file, {:ok, acc} ->
      case read_entity_file(type_dir, file, workspace) do
        {:ok, entity} -> {:cont, {:ok, [entity | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> then(fn
      {:ok, entities} -> {:ok, Enum.reverse(entities)}
      error -> error
    end)
  end

  defp read_entity_file(type_dir, file, workspace) do
    path = Path.join(type_dir, file)

    with {:ok, content} <- safe_read(path, workspace),
         {:ok, entity} <- Entity.parse(content) do
      {:ok, entity}
    else
      {:error, :path_traversal} -> {:error, :path_traversal}
      {:error, reason} -> {:error, {:parse_error, file, reason}}
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

    Logger.info("[Brain] ensure_initialized brain_dir=#{Path.relative_to_cwd(brain_dir)}")

    with :ok <- File.mkdir_p(brain_dir),
         :ok <- File.mkdir_p(schemas_dir),
         {:ok, existing} <- Schema.list_types(workspace) do
      maybe_seed(workspace, existing)
    end
  end

  defp maybe_seed(workspace, []) do
    Logger.info("[Brain] no schemas found, seeding defaults")
    Seeds.seed(workspace)
  end

  defp maybe_seed(_workspace, existing) do
    Logger.info(fn -> "[Brain] already initialized, schemas=#{inspect(existing)}" end)
    {:ok, []}
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
