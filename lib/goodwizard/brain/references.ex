defmodule Goodwizard.Brain.References do
  @moduledoc """
  Reference field detection, validation, and cleanup for brain entities.

  Extracts reference metadata from JSON Schema properties, cleans stale
  references on read, validates references explicitly, and sweeps stale
  references from disk after entity deletion.
  """

  require Logger

  alias Goodwizard.Brain.{Id, Paths, Schema}

  # Derive UUID pattern from Id.id_pattern/0, stripping the outer ^...$ anchors
  @uuid_pattern Id.id_pattern()
                |> String.replace_prefix("^", "")
                |> String.replace_suffix("$", "")
  @uuid_suffix "/" <> @uuid_pattern <> "$"

  # Polymorphic pattern prefix: "^[a-z_]+/"
  @poly_prefix "^[a-z_]+/"

  @doc """
  Extracts reference field metadata from a resolved JSON Schema.

  Returns a list of ref descriptors:
  - `{field_name, :single_ref, target_type}` — single entity reference
  - `{field_name, :ref_list, target_type}` — typed entity reference list
  - `{field_name, :poly_ref_list}` — polymorphic reference list (target resolved at runtime)
  """
  @spec ref_fields(ExJsonSchema.Schema.Root.t()) :: [
          {String.t(), :single_ref, String.t()}
          | {String.t(), :ref_list, String.t()}
          | {String.t(), :poly_ref_list}
        ]
  def ref_fields(%ExJsonSchema.Schema.Root{schema: schema}) do
    properties = Map.get(schema, "properties", %{})

    properties
    |> Enum.flat_map(fn {field_name, prop} -> classify_property(field_name, prop) end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp classify_property(field_name, %{"type" => "string", "pattern" => pattern}) do
    case extract_typed_target(pattern) do
      {:ok, target_type} -> [{field_name, :single_ref, target_type}]
      :not_ref -> []
    end
  end

  defp classify_property(field_name, %{"type" => "array", "items" => %{"pattern" => pattern}}) do
    if String.starts_with?(pattern, @poly_prefix) do
      [{field_name, :poly_ref_list}]
    else
      case extract_typed_target(pattern) do
        {:ok, target_type} -> [{field_name, :ref_list, target_type}]
        :not_ref -> []
      end
    end
  end

  defp classify_property(_field_name, _prop), do: []

  # Extracts the target type from a typed ref pattern string like "^companies/<uuid>$"
  defp extract_typed_target(pattern) do
    if String.contains?(pattern, @uuid_suffix) do
      # Strip leading "^" if present, then extract everything before "/<uuid>$"
      trimmed = String.replace_prefix(pattern, "^", "")

      case String.split(trimmed, "/", parts: 2) do
        [target_type, _rest] when target_type != "" -> {:ok, target_type}
        _ -> :not_ref
      end
    else
      :not_ref
    end
  end

  @doc """
  Removes stale entity references from a data map.

  - Single refs pointing to nonexistent entities are set to `nil`
  - List refs have nonexistent entries filtered out
  - Polymorphic refs have nonexistent entries filtered out (type parsed from value)

  Does NOT modify the file on disk.
  """
  @spec clean_data(String.t(), ExJsonSchema.Schema.Root.t(), map()) :: map()
  def clean_data(workspace, schema, data) do
    clean_data_with_refs(workspace, ref_fields(schema), data)
  end

  @doc """
  Like `clean_data/3` but accepts pre-computed ref field descriptors.

  Use this when processing multiple entities of the same type to avoid
  recomputing `ref_fields/1` per entity.
  """
  @spec clean_data_with_refs(String.t(), list(), map()) :: map()
  def clean_data_with_refs(workspace, refs, data) do
    Enum.reduce(refs, data, &clean_field(workspace, &1, &2))
  end

  defp clean_field(workspace, {field_name, :single_ref, target_type}, data) do
    case Map.get(data, field_name) do
      nil ->
        data

      ref when is_binary(ref) ->
        if ref_exists?(workspace, target_type, ref) do
          data
        else
          Map.put(data, field_name, nil)
        end

      _ ->
        data
    end
  end

  defp clean_field(workspace, {field_name, :ref_list, target_type}, data) do
    case Map.get(data, field_name) do
      refs when is_list(refs) ->
        Map.put(data, field_name, Enum.filter(refs, &ref_exists?(workspace, target_type, &1)))

      _ ->
        data
    end
  end

  defp clean_field(workspace, {field_name, :poly_ref_list}, data) do
    case Map.get(data, field_name) do
      refs when is_list(refs) ->
        Map.put(data, field_name, Enum.filter(refs, &poly_ref_exists?(workspace, &1)))

      _ ->
        data
    end
  end

  @doc """
  Returns a list of stale references without modifying data.

  Each stale reference is returned as `{field_name, stale_ref_value}`.
  Returns an empty list if all references are valid.
  """
  @spec validate(String.t(), ExJsonSchema.Schema.Root.t(), map()) :: [
          {String.t(), String.t()}
        ]
  def validate(workspace, schema, data) do
    refs = ref_fields(schema)

    Enum.flat_map(refs, fn ref_field ->
      validate_field(workspace, ref_field, data)
    end)
  end

  defp validate_field(workspace, {field_name, :single_ref, target_type}, data) do
    case Map.get(data, field_name) do
      nil ->
        []

      ref when is_binary(ref) ->
        if ref_exists?(workspace, target_type, ref),
          do: [],
          else: [{field_name, ref}]

      _ ->
        []
    end
  end

  defp validate_field(workspace, {field_name, :ref_list, target_type}, data) do
    case Map.get(data, field_name) do
      refs when is_list(refs) ->
        refs
        |> Enum.reject(&ref_exists?(workspace, target_type, &1))
        |> Enum.map(&{field_name, &1})

      _ ->
        []
    end
  end

  defp validate_field(workspace, {field_name, :poly_ref_list}, data) do
    case Map.get(data, field_name) do
      refs when is_list(refs) ->
        refs
        |> Enum.reject(&poly_ref_exists?(workspace, &1))
        |> Enum.map(&{field_name, &1})

      _ ->
        []
    end
  end

  @doc """
  Scans all entity types for references to a deleted entity and rewrites
  affected files to remove stale references.

  Finds entity types with typed ref fields pointing at `deleted_type` and
  types with polymorphic ref fields, reads their entities, and rewrites
  any files containing stale references to the deleted entity.

  Failures are logged but do not propagate.
  """
  @spec sweep_stale(String.t(), String.t(), String.t()) :: :ok
  def sweep_stale(workspace, deleted_type, deleted_id) do
    deleted_ref = "#{deleted_type}/#{deleted_id}"

    with {:ok, types} <- Schema.list_types(workspace) do
      types
      |> Enum.each(fn type ->
        case Schema.load(workspace, type) do
          {:ok, schema} ->
            refs = ref_fields(schema)
            sweep_type_if_relevant(workspace, type, schema, refs, deleted_type, deleted_ref)

          {:error, reason} ->
            Logger.warning(
              "[Brain.References] sweep: failed to load schema for #{type}: #{inspect(reason)}"
            )
        end
      end)
    else
      {:error, reason} ->
        Logger.warning("[Brain.References] sweep: failed to list types: #{inspect(reason)}")
    end

    :ok
  end

  defp sweep_type_if_relevant(workspace, type, schema, refs, deleted_type, deleted_ref) do
    has_typed_ref =
      Enum.any?(refs, fn
        {_, :single_ref, target} -> target == deleted_type
        {_, :ref_list, target} -> target == deleted_type
        _ -> false
      end)

    has_poly_ref =
      Enum.any?(refs, fn
        {_, :poly_ref_list} -> true
        _ -> false
      end)

    if has_typed_ref or has_poly_ref do
      sweep_entities_of_type(workspace, type, schema, deleted_ref)
    end
  end

  defp sweep_entities_of_type(workspace, type, schema, deleted_ref) do
    refs = ref_fields(schema)

    with {:ok, type_dir} <- Paths.entity_type_dir(workspace, type),
         {:ok, files} <- list_md_files(type_dir) do
      Enum.each(files, fn file ->
        sweep_single_entity(type, type_dir, file, refs, deleted_ref)
      end)
    else
      {:error, reason} ->
        Logger.warning(
          "[Brain.References] sweep: failed to list entities for #{type}: #{inspect(reason)}"
        )
    end
  end

  defp sweep_single_entity(type, type_dir, file, refs, deleted_ref) do
    path = Path.join(type_dir, file)
    id = String.trim_trailing(file, ".md")
    lock_file = path <> ".lock"

    case :file.open(lock_file, [:write, :exclusive]) do
      {:ok, lock_fd} ->
        try do
          with {:ok, content} <- File.read(path),
               {:ok, {data, body}} <- Goodwizard.Brain.Entity.parse(content) do
            cleaned = clean_data_for_ref(data, refs, deleted_ref)

            if cleaned != data do
              case File.write(path, Goodwizard.Brain.Entity.serialize(cleaned, body)) do
                :ok ->
                  Logger.info("[Brain.References] sweep: cleaned refs in #{type}/#{id}")

                {:error, reason} ->
                  Logger.warning(
                    "[Brain.References] sweep: failed to write #{type}/#{id}: #{inspect(reason)}"
                  )
              end
            end
          else
            {:error, reason} ->
              Logger.warning(
                "[Brain.References] sweep: failed to read #{type}/#{file}: #{inspect(reason)}"
              )
          end
        after
          :file.close(lock_fd)
          File.rm(lock_file)
        end

      {:error, :eexist} ->
        Logger.warning(
          "[Brain.References] sweep: skipped #{type}/#{id} (locked by concurrent update)"
        )

      {:error, reason} ->
        Logger.warning(
          "[Brain.References] sweep: failed to lock #{type}/#{id}: #{inspect(reason)}"
        )
    end
  end

  # Cleans data specifically targeting a single deleted reference.
  # More targeted than clean_data/3 which checks all refs for existence.
  defp clean_data_for_ref(data, refs, deleted_ref) do
    Enum.reduce(refs, data, fn ref_field, acc ->
      clean_field_for_ref(ref_field, acc, deleted_ref)
    end)
  end

  # Sets stale single ref to nil (consistent with clean_data's clean_field behavior)
  defp clean_field_for_ref({field_name, :single_ref, _target_type}, data, deleted_ref) do
    if Map.get(data, field_name) == deleted_ref do
      Map.put(data, field_name, nil)
    else
      data
    end
  end

  defp clean_field_for_ref({field_name, :ref_list, _target_type}, data, deleted_ref) do
    case Map.get(data, field_name) do
      refs when is_list(refs) ->
        Map.put(data, field_name, Enum.reject(refs, &(&1 == deleted_ref)))

      _ ->
        data
    end
  end

  defp clean_field_for_ref({field_name, :poly_ref_list}, data, deleted_ref) do
    case Map.get(data, field_name) do
      refs when is_list(refs) ->
        Map.put(data, field_name, Enum.reject(refs, &(&1 == deleted_ref)))

      _ ->
        data
    end
  end

  @max_sweep_entities 1_000

  defp list_md_files(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        md_files =
          files
          |> Enum.filter(&String.ends_with?(&1, ".md"))
          |> Enum.take(@max_sweep_entities)

        {:ok, md_files}

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Checks whether a typed reference target exists on disk.
  # Extracts the ID from "type/uuid" format and checks the entity path.
  defp ref_exists?(workspace, target_type, ref) when is_binary(ref) do
    case extract_id_from_ref(target_type, ref) do
      {:ok, id} ->
        case Paths.entity_path(workspace, target_type, id) do
          {:ok, path} -> File.exists?(path)
          _ -> false
        end

      :error ->
        false
    end
  end

  defp ref_exists?(_workspace, _target_type, _ref), do: false

  # Checks whether a polymorphic reference target exists.
  # Parses "type/uuid" to determine both the target type and ID.
  defp poly_ref_exists?(workspace, ref) when is_binary(ref) do
    case parse_poly_ref(ref) do
      {:ok, target_type, id} ->
        case Paths.entity_path(workspace, target_type, id) do
          {:ok, path} -> File.exists?(path)
          _ -> false
        end

      :error ->
        false
    end
  end

  defp poly_ref_exists?(_workspace, _ref), do: false

  defp extract_id_from_ref(target_type, ref) do
    prefix = target_type <> "/"
    prefix_len = byte_size(prefix)

    if String.starts_with?(ref, prefix) do
      {:ok, binary_part(ref, prefix_len, byte_size(ref) - prefix_len)}
    else
      :error
    end
  end

  defp parse_poly_ref(ref) do
    case String.split(ref, "/", parts: 2) do
      [type, id] when type != "" and id != "" -> {:ok, type, id}
      _ -> :error
    end
  end
end
