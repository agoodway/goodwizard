defmodule Mix.Tasks.Goodwizard.MigrateContacts do
  @moduledoc """
  Migrates existing entity files from scalar contact fields to multi-value arrays.

      $ mix goodwizard.migrate_contacts

  Scans all people and companies entity files and converts:
  - `email` (string) → `emails` (array of `{type: "primary", value: <email>}`)
  - `phone` (string) → `phones` (array of `{type: "primary", value: <phone>}`)
  - `location` (string) → `addresses` (array of `{type: "primary", city: <location>}`)

  Entities already using the new array format are skipped.
  Reports a summary of migrated vs skipped entities.
  """
  use Mix.Task

  alias Goodwizard.Brain.{Entity, Paths, Schema, Seeds}

  @shortdoc "Migrate scalar email/phone/location fields to multi-value arrays"

  @people_fields %{
    "email" => "emails",
    "phone" => "phones"
  }

  @company_fields %{
    "location" => "addresses"
  }

  @schema_types ~w(people companies)

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    workspace = Goodwizard.Config.workspace()

    Mix.shell().info("Migrating contact fields in #{workspace}...")

    people_result = migrate_type(workspace, "people", @people_fields)
    company_result = migrate_type(workspace, "companies", @company_fields)

    upgrade_schemas(workspace)

    report(people_result, "people")
    report(company_result, "companies")
  end

  @doc false
  def migrate_type(workspace, entity_type, field_map) do
    case Paths.entity_type_dir(workspace, entity_type) do
      {:ok, type_dir} ->
        case File.ls(type_dir) do
          {:ok, files} ->
            files
            |> Enum.filter(&String.ends_with?(&1, ".md"))
            |> Enum.reduce(%{migrated: 0, skipped: 0, errors: []}, fn file, acc ->
              path = Path.join(type_dir, file)
              migrate_file(path, field_map, acc)
            end)

          {:error, :enoent} ->
            %{migrated: 0, skipped: 0, errors: []}
        end

      {:error, reason} ->
        %{migrated: 0, skipped: 0, errors: [{"entity_type:#{entity_type}", reason}]}
    end
  end

  defp migrate_file(path, field_map, acc) do
    with {:ok, content} <- File.read(path),
         {:ok, {data, body}} <- Entity.parse(content) do
      case migrate_data(data, field_map) do
        {:migrated, new_data} ->
          serialized = Entity.serialize(new_data, body)
          atomic_write(path, serialized, acc)

        :skip ->
          %{acc | skipped: acc.skipped + 1}
      end
    else
      {:error, reason} ->
        %{acc | errors: [{path, reason} | acc.errors]}
    end
  end

  defp atomic_write(path, content, acc) do
    tmp_path = path <> ".tmp"

    with :ok <- File.write(tmp_path, content),
         {:ok, _content} <- File.read(tmp_path),
         :ok <- File.rename(tmp_path, path) do
      %{acc | migrated: acc.migrated + 1}
    else
      {:error, reason} ->
        File.rm(tmp_path)
        %{acc | errors: [{path, reason} | acc.errors]}
    end
  end

  defp upgrade_schemas(workspace) do
    Enum.each(@schema_types, fn type ->
      schema = Seeds.schema_for(type)
      Schema.save(workspace, type, schema)
    end)
  end

  @doc false
  def migrate_data(data, field_map) do
    changes =
      Enum.reduce(field_map, [], fn {old_key, new_key}, changes ->
        case Map.get(data, old_key) do
          nil -> changes
          value when is_binary(value) -> [{old_key, new_key, value} | changes]
          _ -> changes
        end
      end)

    if changes == [] do
      :skip
    else
      new_data =
        Enum.reduce(changes, data, fn {old_key, new_key, value}, acc ->
          acc
          |> Map.delete(old_key)
          |> Map.put(new_key, [convert_value(old_key, value)])
        end)

      {:migrated, new_data}
    end
  end

  defp convert_value("location", value) do
    %{"type" => "primary", "city" => value}
  end

  defp convert_value(_field, value) do
    %{"type" => "primary", "value" => value}
  end

  defp report(%{migrated: migrated, skipped: skipped, errors: errors}, type) do
    Mix.shell().info("  #{type}: #{migrated} migrated, #{skipped} skipped")

    for {path, reason} <- errors do
      Mix.shell().error("  #{type} error: #{path} — #{inspect(reason)}")
    end
  end
end
