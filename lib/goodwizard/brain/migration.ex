defmodule Goodwizard.Brain.Migration do
  @moduledoc """
  Applies schema migrations to brain entities.
  """

  alias Goodwizard.Brain.{Entity, Paths, Schema}

  @type migration_summary :: %{
          total: non_neg_integer(),
          migrated: non_neg_integer(),
          skipped: non_neg_integer(),
          errors: [map()]
        }

  @type dry_run_summary :: %{
          total: non_neg_integer(),
          migrated: non_neg_integer(),
          skipped: non_neg_integer(),
          errors: [map()],
          changes: [map()]
        }

  @doc """
  Loads a migration definition from disk.
  """
  @spec load(String.t(), String.t(), integer(), integer()) :: {:ok, map()} | {:error, term()}
  def load(workspace, entity_type, from_version, to_version) do
    with {:ok, path} <- Paths.migration_path(workspace, entity_type, from_version, to_version),
         {:ok, content} <- File.read(path),
         {:ok, migration_definition} <- Jason.decode(content) do
      {:ok, migration_definition}
    end
  end

  @doc """
  Applies migration operations to an entity frontmatter map in order.
  """
  @spec apply_operations(map(), list()) :: {:ok, map()} | {:error, term()}
  def apply_operations(frontmatter, operations)
      when is_map(frontmatter) and is_list(operations) do
    operations
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, frontmatter}, fn {operation, index}, {:ok, acc} ->
      case apply_operation(acc, operation) do
        {:ok, updated} ->
          {:cont, {:ok, updated}}

        {:error, reason} ->
          {:halt, {:error, {:invalid_operation, index, reason}}}
      end
    end)
  end

  def apply_operations(_frontmatter, _operations), do: {:error, :invalid_operations}

  @doc """
  Executes a migration against all entities of a type and writes changes to disk.
  """
  @spec execute(String.t(), String.t(), map()) :: {:ok, migration_summary()} | {:error, term()}
  def execute(workspace, entity_type, migration_definition) do
    run(workspace, entity_type, migration_definition, false)
  end

  @doc """
  Executes a migration in dry-run mode and returns entity diffs without writing files.
  """
  @spec dry_run(String.t(), String.t(), map()) ::
          {:ok, dry_run_summary()} | {:error, term()}
  def dry_run(workspace, entity_type, migration_definition) do
    run(workspace, entity_type, migration_definition, true)
  end

  @spec run(String.t(), String.t(), map(), boolean()) ::
          {:ok, migration_summary()} | {:ok, dry_run_summary()} | {:error, term()}
  defp run(workspace, entity_type, migration_definition, dry_run?) do
    with {:ok, operations} <- migration_operations(migration_definition),
         {:ok, schema} <- Schema.load(workspace, entity_type),
         {:ok, type_dir} <- Paths.entity_type_dir(workspace, entity_type),
         {:ok, files} <- list_entity_files(type_dir) do
      summary = process_entities(type_dir, files, schema, operations, dry_run?)

      if dry_run? do
        {:ok, summary}
      else
        {:ok, Map.drop(summary, [:changes])}
      end
    end
  end

  @spec migration_operations(map()) :: {:ok, list()} | {:error, term()}
  defp migration_operations(migration_definition) when is_map(migration_definition) do
    operations = migration_value(migration_definition, "operations", :operations)

    if is_list(operations) do
      {:ok, operations}
    else
      {:error, {:invalid_migration_definition, :operations}}
    end
  end

  defp migration_operations(_migration_definition),
    do: {:error, {:invalid_migration_definition, :format}}

  @spec list_entity_files(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  defp list_entity_files(type_dir) do
    case File.ls(type_dir) do
      {:ok, files} ->
        entity_files =
          files
          |> Enum.filter(&String.ends_with?(&1, ".md"))
          |> Enum.sort()

        {:ok, entity_files}

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec process_entities(
          String.t(),
          [String.t()],
          ExJsonSchema.Schema.Root.t(),
          [map()],
          boolean()
        ) ::
          dry_run_summary()
  defp process_entities(type_dir, files, schema, operations, dry_run?) do
    Enum.reduce(files, base_summary(), fn file, summary ->
      path = Path.join(type_dir, file)
      id = Path.rootname(file)

      case migrate_entity(path, id, schema, operations, dry_run?) do
        {:migrated, change} ->
          %{
            summary
            | total: summary.total + 1,
              migrated: summary.migrated + 1,
              changes: maybe_add_change(summary.changes, change, dry_run?)
          }

        :skipped ->
          %{summary | total: summary.total + 1, skipped: summary.skipped + 1}

        {:error, error} ->
          %{summary | total: summary.total + 1, errors: [error | summary.errors]}
      end
    end)
    |> then(fn summary ->
      %{summary | errors: Enum.reverse(summary.errors), changes: Enum.reverse(summary.changes)}
    end)
  end

  @spec base_summary() :: dry_run_summary()
  defp base_summary do
    %{total: 0, migrated: 0, skipped: 0, errors: [], changes: []}
  end

  @spec maybe_add_change([map()], map(), boolean()) :: [map()]
  defp maybe_add_change(changes, change, true), do: [change | changes]
  defp maybe_add_change(changes, _change, false), do: changes

  @spec migrate_entity(String.t(), String.t(), ExJsonSchema.Schema.Root.t(), [map()], boolean()) ::
          {:migrated, map()} | :skipped | {:error, map()}
  defp migrate_entity(path, fallback_id, schema, operations, dry_run?) do
    with {:ok, content} <- File.read(path),
         {:ok, {data, body}} <- Entity.parse(content) do
      process_loaded_entity(path, fallback_id, data, body, schema, operations, dry_run?)
    else
      {:error, reason} ->
        {:error, %{id: fallback_id, error: reason}}
    end
  end

  @spec process_loaded_entity(
          String.t(),
          String.t(),
          map(),
          String.t(),
          ExJsonSchema.Schema.Root.t(),
          [map()],
          boolean()
        ) ::
          {:migrated, map()} | :skipped | {:error, map()}
  defp process_loaded_entity(path, fallback_id, data, body, schema, operations, dry_run?) do
    id = Map.get(data, "id", fallback_id)

    case Schema.validate(schema, data) do
      :ok ->
        :skipped

      {:error, _} ->
        migrate_invalid_entity(path, id, data, body, schema, operations, dry_run?)
    end
  end

  @spec migrate_invalid_entity(
          String.t(),
          String.t(),
          map(),
          String.t(),
          ExJsonSchema.Schema.Root.t(),
          [map()],
          boolean()
        ) ::
          {:migrated, map()} | {:error, map()}
  defp migrate_invalid_entity(path, id, data, body, schema, operations, dry_run?) do
    with {:ok, migrated_data} <- apply_operations(data, operations),
         migrated_data <- put_migration_timestamp(migrated_data),
         :ok <- Schema.validate(schema, migrated_data),
         :ok <- maybe_write_entity(path, migrated_data, body, dry_run?) do
      {:migrated, %{id: id, before: data, after: migrated_data}}
    else
      {:error, reason} ->
        {:error, %{id: id, error: reason}}
    end
  end

  @spec put_migration_timestamp(map()) :: map()
  defp put_migration_timestamp(data) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    Map.put(data, "updated_at", now)
  end

  @spec maybe_write_entity(String.t(), map(), String.t(), boolean()) :: :ok | {:error, term()}
  defp maybe_write_entity(_path, _data, _body, true), do: :ok

  defp maybe_write_entity(path, data, body, false) do
    File.write(path, Entity.serialize(data, body))
  end

  @spec apply_operation(map(), map()) :: {:ok, map()} | {:error, term()}
  defp apply_operation(data, operation) when is_map(operation) do
    case migration_value(operation, "op", :op) do
      "add_field" ->
        add_field(data, operation)

      "rename_field" ->
        rename_field(data, operation)

      "remove_field" ->
        remove_field(data, operation)

      "set_default" ->
        set_default(data, operation)

      other ->
        {:error, {:unsupported_operation, other}}
    end
  end

  defp apply_operation(_data, _operation), do: {:error, :operation_must_be_a_map}

  @spec add_field(map(), map()) :: {:ok, map()} | {:error, term()}
  defp add_field(data, operation) do
    case migration_value(operation, "field", :field) do
      field when is_binary(field) and field != "" ->
        if Map.has_key?(data, field) do
          {:ok, data}
        else
          default = migration_value(operation, "default", :default)
          {:ok, Map.put(data, field, default)}
        end

      _ ->
        {:error, :invalid_field}
    end
  end

  @spec rename_field(map(), map()) :: {:ok, map()} | {:error, term()}
  defp rename_field(data, operation) do
    from = migration_value(operation, "from", :from)
    to = migration_value(operation, "to", :to)

    cond do
      not (is_binary(from) and from != "") ->
        {:error, :invalid_from_field}

      not (is_binary(to) and to != "") ->
        {:error, :invalid_to_field}

      Map.has_key?(data, from) ->
        value = Map.fetch!(data, from)
        {:ok, data |> Map.delete(from) |> Map.put(to, value)}

      true ->
        {:ok, data}
    end
  end

  @spec remove_field(map(), map()) :: {:ok, map()} | {:error, term()}
  defp remove_field(data, operation) do
    case migration_value(operation, "field", :field) do
      field when is_binary(field) and field != "" ->
        {:ok, Map.delete(data, field)}

      _ ->
        {:error, :invalid_field}
    end
  end

  @spec set_default(map(), map()) :: {:ok, map()} | {:error, term()}
  defp set_default(data, operation) do
    case migration_value(operation, "field", :field) do
      field when is_binary(field) and field != "" ->
        if Map.has_key?(data, field) do
          {:ok, data}
        else
          value = migration_value(operation, "value", :value)
          {:ok, Map.put(data, field, value)}
        end

      _ ->
        {:error, :invalid_field}
    end
  end

  @spec migration_value(map(), String.t(), atom()) :: term()
  defp migration_value(map, string_key, atom_key) do
    Map.get(map, string_key) || Map.get(map, atom_key)
  end
end
