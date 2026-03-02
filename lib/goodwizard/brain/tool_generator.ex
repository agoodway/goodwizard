defmodule Goodwizard.Brain.ToolGenerator do
  @moduledoc """
  Generates typed Jido.Action modules at runtime from brain JSON Schema files.

  Instead of generic `create_entity(type, data)`, produces specific tools like
  `create_person(name, email, company)` with proper field-level parameters,
  descriptions, and validation.

  Uses `Module.create/3` to compile quoted AST that invokes `use Jido.Action`.
  Generated modules live under `Goodwizard.Actions.Brain.Generated.*`.
  """

  require Logger

  alias Goodwizard.Brain.{Paths, SchemaMapper}

  @cache_key "brain_tools:generated_modules"
  @generated_namespace Goodwizard.Actions.Brain.Generated

  @doc """
  Generates create + update action modules for all entity types in the workspace.

  Returns `{:ok, [module()]}` with all successfully generated modules.
  """
  @spec generate_all(String.t()) :: {:ok, [module()]}
  def generate_all(workspace) do
    schemas_dir = Paths.schemas_dir(workspace)

    case File.ls(schemas_dir) do
      {:ok, files} ->
        modules = generate_modules_from_files(workspace, files)
        Goodwizard.Cache.put(@cache_key, modules)
        Logger.info("[ToolGenerator] Generated #{length(modules)} knowledge base tools")
        {:ok, modules}

      {:error, :enoent} ->
        Logger.info("[ToolGenerator] No schemas directory found, skipping")
        Goodwizard.Cache.put(@cache_key, [])
        {:ok, []}

      {:error, reason} ->
        Logger.warning("[ToolGenerator] Failed to list schemas: #{inspect(reason)}")
        {:ok, []}
    end
  end

  @doc """
  Generates create + update action modules for a single entity type.

  Purges old modules for this type first (if any), then creates new ones.
  Updates the cached modules list.

  Returns `{:ok, [module()]}` with the generated modules.
  """
  @spec generate_for_type(String.t(), String.t()) :: {:ok, [module()]} | {:error, term()}
  def generate_for_type(workspace, entity_type) do
    with {:ok, modules} <- build_type_modules(workspace, entity_type) do
      update_cache(entity_type, modules)
      {:ok, modules}
    end
  end

  @doc """
  Returns the list of all currently generated modules from cache.
  """
  @spec generated_modules() :: [module()]
  def generated_modules do
    Goodwizard.Cache.get(@cache_key) || []
  end

  @doc """
  Purges all generated modules and clears the cache.
  """
  @spec purge_all() :: :ok
  def purge_all do
    modules = generated_modules()

    Enum.each(modules, &purge_module/1)
    Goodwizard.Cache.put(@cache_key, [])
    :ok
  end

  # --- Private ---

  defp generate_modules_from_files(workspace, files) do
    types =
      files
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.map(&String.replace_suffix(&1, ".json", ""))

    Enum.flat_map(types, fn type ->
      case build_type_modules(workspace, type) do
        {:ok, mods} ->
          mods

        {:error, reason} ->
          Logger.warning("[ToolGenerator] Failed to generate for #{type}: #{inspect(reason)}")

          []
      end
    end)
  end

  defp build_type_modules(workspace, entity_type) do
    singular = SchemaMapper.singularize(entity_type)
    create_mod = module_name("Create", singular)
    update_mod = module_name("Update", singular)

    purge_module(create_mod)
    purge_module(update_mod)

    with {:ok, schema_map} <- load_raw_schema(workspace, entity_type),
         {:ok, create} <- build_create_module(create_mod, entity_type, singular, schema_map),
         {:ok, update} <- build_update_module(update_mod, entity_type, singular, schema_map) do
      {:ok, [create, update]}
    end
  end

  defp module_name(prefix, singular) do
    pascal = singular |> Macro.camelize()
    Module.concat(@generated_namespace, "#{prefix}#{pascal}")
  end

  defp load_raw_schema(workspace, entity_type) do
    with {:ok, path} <- Paths.schema_path(workspace, entity_type),
         {:ok, content} <- File.read(path),
         {:ok, schema_map} <- Jason.decode(content) do
      {:ok, schema_map}
    else
      {:error, :enoent} -> {:error, {:schema_not_found, entity_type}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_create_module(mod_name, entity_type, singular, schema_map) do
    action_name = "create_#{singular}"
    schema_title = Map.get(schema_map, "title", singular)
    description = "Create a new #{schema_title} in the knowledge base"

    with {:ok, schema_kw} <- SchemaMapper.for_create(schema_map) do
      body =
        quote do
          use Jido.Action,
            name: unquote(action_name),
            description: unquote(description),
            schema: unquote(Macro.escape(schema_kw))

          alias Goodwizard.Actions.Brain.Helpers

          @entity_type unquote(entity_type)

          @impl true
          def run(params, context) do
            workspace = Helpers.workspace(context)
            body = Map.get(params, :body, "")

            data =
              params
              |> Map.drop([:body, :id])
              |> Map.new(fn {k, v} -> {to_string(k), v} end)

            case Goodwizard.Brain.create(workspace, @entity_type, data, body) do
              {:ok, {id, data, body}} ->
                {:ok, %{id: id, data: Helpers.sanitize_entity_data(data), body: body}}

              {:error, reason} ->
                {:error, Helpers.format_error(reason)}
            end
          end
        end

      create_module(mod_name, body)
    end
  end

  defp build_update_module(mod_name, entity_type, singular, schema_map) do
    action_name = "update_#{singular}"
    schema_title = Map.get(schema_map, "title", singular)
    description = "Update an existing #{schema_title} by ID. Pass only the fields to change."

    with {:ok, schema_kw} <- SchemaMapper.for_update(schema_map) do
      body =
        quote do
          use Jido.Action,
            name: unquote(action_name),
            description: unquote(description),
            schema: unquote(Macro.escape(schema_kw))

          alias Goodwizard.Actions.Brain.Helpers

          @entity_type unquote(entity_type)

          @impl true
          def run(params, context) do
            workspace = Helpers.workspace(context)
            id = params.id
            body = Map.get(params, :body)

            data =
              params
              |> Map.drop([:id, :body])
              |> Map.new(fn {k, v} -> {to_string(k), v} end)

            case Goodwizard.Brain.update(workspace, @entity_type, id, data, body) do
              {:ok, {data, body}} ->
                {:ok, %{data: Helpers.sanitize_entity_data(data), body: body}}

              {:error, reason} ->
                {:error, Helpers.format_error(reason)}
            end
          end
        end

      create_module(mod_name, body)
    end
  end

  defp create_module(mod_name, body) do
    :global.trans({__MODULE__, mod_name}, fn ->
      if Code.ensure_loaded?(mod_name) do
        purge_module(mod_name)
      end

      Module.create(mod_name, body, Macro.Env.location(__ENV__))
    end)

    {:ok, mod_name}
  rescue
    e ->
      Logger.error(
        "[ToolGenerator] Failed to create #{inspect(mod_name)}: #{Exception.message(e)}"
      )

      {:error, {:module_creation_failed, mod_name, Exception.message(e)}}
  end

  defp purge_module(mod) do
    :code.purge(mod)
    :code.delete(mod)
  end

  defp update_cache(entity_type, new_modules) do
    singular = SchemaMapper.singularize(entity_type)
    create_mod = module_name("Create", singular)
    update_mod = module_name("Update", singular)

    current = generated_modules()

    # Remove old modules for this type, add new ones
    updated =
      current
      |> Enum.reject(fn mod -> mod in [create_mod, update_mod] end)
      |> Kernel.++(new_modules)

    Goodwizard.Cache.put(@cache_key, updated)
  end
end
