defmodule Goodwizard.Brain.SchemaTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Brain.{Paths, Schema}

  @test_schema %{
    "$schema" => "http://json-schema.org/draft-07/schema#",
    "title" => "TestEntity",
    "version" => 1,
    "type" => "object",
    "required" => ["id", "name"],
    "properties" => %{
      "id" => %{
        "type" => "string",
        "pattern" => "^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
      },
      "name" => %{"type" => "string"},
      "tags" => %{"type" => "array", "items" => %{"type" => "string"}}
    },
    "additionalProperties" => false
  }

  @migration_v1_to_v2 %{
    "from_version" => 1,
    "to_version" => 2,
    "operations" => [
      %{"op" => "add_field", "field" => "nickname", "default" => nil}
    ]
  }

  setup do
    workspace = Path.join(System.tmp_dir!(), "brain_schema_test_#{:rand.uniform(100_000)}")
    schemas_dir = Path.join([workspace, "brain", "schemas"])
    File.mkdir_p!(schemas_dir)
    on_exit(fn -> File.rm_rf!(workspace) end)
    %{workspace: workspace, schemas_dir: schemas_dir}
  end

  describe "save/3 and load/2" do
    test "saves and loads a schema", %{workspace: workspace} do
      assert :ok = Schema.save(workspace, "test_entity", @test_schema)
      assert {:ok, resolved} = Schema.load(workspace, "test_entity")
      assert %ExJsonSchema.Schema.Root{} = resolved
    end

    test "save creates pretty-printed JSON file", %{
      workspace: workspace,
      schemas_dir: schemas_dir
    } do
      Schema.save(workspace, "test_entity", @test_schema)
      content = File.read!(Path.join(schemas_dir, "test_entity.json"))
      assert String.contains?(content, "\n")
      assert {:ok, decoded} = Jason.decode(content)
      assert decoded["title"] == "TestEntity"
      assert decoded["version"] == 1
    end

    test "save allows updating a schema only when version increments by one", %{
      workspace: workspace
    } do
      assert :ok = Schema.save(workspace, "test_entity", @test_schema)

      updated_schema =
        @test_schema
        |> Map.put("version", 2)
        |> Map.put("title", "TestEntityV2")

      assert :ok = Schema.save(workspace, "test_entity", updated_schema, @migration_v1_to_v2)
      assert {:ok, resolved} = Schema.load(workspace, "test_entity")
      assert %ExJsonSchema.Schema.Root{} = resolved
    end

    test "save rejects update when new version is not current+1", %{workspace: workspace} do
      assert :ok = Schema.save(workspace, "test_entity", @test_schema)

      same_version = Map.put(@test_schema, "title", "TestEntitySameVersion")
      skipped_version = Map.put(@test_schema, "version", 3)

      assert {:error, {:version_mismatch, 2, 1}} =
               Schema.save(workspace, "test_entity", same_version)

      assert {:error, {:version_mismatch, 2, 3}} =
               Schema.save(workspace, "test_entity", skipped_version)
    end

    test "save rejects schema updates without a migration definition", %{workspace: workspace} do
      assert :ok = Schema.save(workspace, "test_entity", @test_schema)

      updated_schema =
        @test_schema
        |> Map.put("version", 2)
        |> Map.put("title", "TestEntityV2")

      assert {:error, :migration_required} = Schema.save(workspace, "test_entity", updated_schema)
    end

    test "save preserves explicit false values when reading migration keys", %{
      workspace: workspace
    } do
      assert :ok = Schema.save(workspace, "test_entity", @test_schema)

      updated_schema =
        @test_schema
        |> Map.put("version", 2)
        |> Map.put("title", "TestEntityV2")

      invalid_migration = %{
        "from_version" => false,
        :from_version => 1,
        "to_version" => 2,
        :to_version => 2,
        "operations" => []
      }

      assert {:error, {:invalid_migration_definition, :from_version}} =
               Schema.save(workspace, "test_entity", updated_schema, invalid_migration)
    end

    test "save archives current schema before overwrite and stores migration", %{
      workspace: workspace
    } do
      assert :ok = Schema.save(workspace, "test_entity", @test_schema)

      updated_schema =
        @test_schema
        |> Map.put("version", 2)
        |> Map.put("title", "TestEntityV2")

      assert :ok = Schema.save(workspace, "test_entity", updated_schema, @migration_v1_to_v2)

      assert {:ok, history_path} = Paths.schema_history_path(workspace, "test_entity", 1)

      assert {:ok, history_content} = File.read(history_path)
      assert {:ok, history_schema} = Jason.decode(history_content)
      assert history_schema["version"] == 1
      assert history_schema["title"] == "TestEntity"

      assert {:ok, migration_path} = Paths.migration_path(workspace, "test_entity", 1, 2)

      assert {:ok, migration_content} = File.read(migration_path)
      assert {:ok, stored_migration} = Jason.decode(migration_content)
      assert stored_migration["from_version"] == 1
      assert stored_migration["to_version"] == 2
      assert is_list(stored_migration["operations"])
    end

    test "load returns error for non-existent schema", %{workspace: workspace} do
      assert {:error, :enoent} = Schema.load(workspace, "nonexistent")
    end

    test "load returns error for corrupted JSON", %{
      workspace: workspace,
      schemas_dir: schemas_dir
    } do
      File.write!(Path.join(schemas_dir, "broken.json"), "not valid json{{{")
      assert {:error, %Jason.DecodeError{}} = Schema.load(workspace, "broken")
    end

    test "load returns error for invalid schema structure", %{
      workspace: workspace,
      schemas_dir: schemas_dir
    } do
      invalid_schema = %{"$ref" => "#/definitions/nonexistent"}
      File.write!(Path.join(schemas_dir, "invalid.json"), Jason.encode!(invalid_schema))
      assert {:error, {:schema_resolution_error, _}} = Schema.load(workspace, "invalid")
    end
  end

  describe "validate/2" do
    setup %{workspace: workspace} do
      Schema.save(workspace, "test_entity", @test_schema)
      {:ok, resolved} = Schema.load(workspace, "test_entity")
      %{resolved: resolved}
    end

    test "validates correct data", %{resolved: resolved} do
      data = %{"id" => "0193a5e7-8b4c-7f2a-9d1e-3b5c6d7e8f9a", "name" => "Test"}
      assert :ok = Schema.validate(resolved, data)
    end

    test "validates data with optional fields", %{resolved: resolved} do
      data = %{
        "id" => "0193a5e7-8b4c-7f2a-9d1e-3b5c6d7e8f9a",
        "name" => "Test",
        "tags" => ["foo", "bar"]
      }

      assert :ok = Schema.validate(resolved, data)
    end

    test "rejects data missing required field", %{resolved: resolved} do
      data = %{"id" => "0193a5e7-8b4c-7f2a-9d1e-3b5c6d7e8f9a"}
      assert {:error, errors} = Schema.validate(resolved, data)
      assert is_list(errors)
      assert errors != []
    end

    test "rejects data with wrong type", %{resolved: resolved} do
      data = %{"id" => "0193a5e7-8b4c-7f2a-9d1e-3b5c6d7e8f9a", "name" => 123}
      assert {:error, _} = Schema.validate(resolved, data)
    end

    test "rejects data with invalid id pattern", %{resolved: resolved} do
      data = %{"id" => "AB", "name" => "Test"}
      assert {:error, _} = Schema.validate(resolved, data)
    end

    test "rejects additional properties", %{resolved: resolved} do
      data = %{
        "id" => "0193a5e7-8b4c-7f2a-9d1e-3b5c6d7e8f9a",
        "name" => "Test",
        "extra" => "nope"
      }

      assert {:error, _} = Schema.validate(resolved, data)
    end
  end

  describe "list_types/1" do
    test "lists available entity types", %{workspace: workspace} do
      Schema.save(workspace, "people", @test_schema)
      Schema.save(workspace, "places", @test_schema)
      Schema.save(workspace, "events", @test_schema)

      assert {:ok, types} = Schema.list_types(workspace)
      assert types == ["events", "people", "places"]
    end

    test "returns empty list for empty schemas dir", %{
      workspace: workspace,
      schemas_dir: schemas_dir
    } do
      # Remove any files that might exist
      File.ls!(schemas_dir) |> Enum.each(&File.rm!(Path.join(schemas_dir, &1)))

      assert {:ok, []} = Schema.list_types(workspace)
    end

    test "returns empty list when schemas dir doesn't exist" do
      workspace = Path.join(System.tmp_dir!(), "no_schemas_#{:rand.uniform(100_000)}")
      on_exit(fn -> File.rm_rf!(workspace) end)

      assert {:ok, []} = Schema.list_types(workspace)
    end

    test "ignores non-json files", %{workspace: workspace, schemas_dir: schemas_dir} do
      Schema.save(workspace, "people", @test_schema)
      File.write!(Path.join(schemas_dir, "README.md"), "ignore me")

      assert {:ok, ["people"]} = Schema.list_types(workspace)
    end
  end

  describe "summarize_types/1" do
    @people_schema %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "title" => "Person",
      "type" => "object",
      "required" => ["id", "name", "created_at"],
      "properties" => %{
        "id" => %{"type" => "string"},
        "name" => %{"type" => "string"},
        "emails" => %{
          "type" => "array",
          "description" => "Email addresses",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "type" => %{"type" => "string"},
              "value" => %{"type" => "string"}
            },
            "required" => ["value"]
          }
        },
        "created_at" => %{"type" => "string"},
        "updated_at" => %{"type" => "string"}
      }
    }

    @companies_schema %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "title" => "Company",
      "type" => "object",
      "required" => ["id", "name", "industry"],
      "properties" => %{
        "id" => %{"type" => "string"},
        "name" => %{"type" => "string"},
        "industry" => %{"type" => "string"},
        "website" => %{"type" => "string"},
        "updated_at" => %{"type" => "string"}
      }
    }

    test "returns summaries with required/optional fields, system fields filtered", %{
      workspace: workspace
    } do
      Schema.save(workspace, "people", @people_schema)
      Schema.save(workspace, "companies", @companies_schema)

      assert {:ok, summaries} = Schema.summarize_types(workspace)
      assert length(summaries) == 2

      people = Enum.find(summaries, &(&1.type == "people"))
      assert people.title == "Person"
      assert people.required == ["name"]
      assert people.optional == ["emails"]

      companies = Enum.find(summaries, &(&1.type == "companies"))
      assert companies.title == "Company"
      assert companies.required == ["industry", "name"]
      assert companies.optional == ["website"]
    end

    test "returns empty list when no schemas exist", %{
      workspace: workspace,
      schemas_dir: schemas_dir
    } do
      File.ls!(schemas_dir) |> Enum.each(&File.rm!(Path.join(schemas_dir, &1)))

      assert {:ok, []} = Schema.summarize_types(workspace)
    end

    test "returns empty list when schemas dir doesn't exist" do
      workspace = Path.join(System.tmp_dir!(), "no_schemas_summary_#{:rand.uniform(100_000)}")
      on_exit(fn -> File.rm_rf!(workspace) end)

      assert {:ok, []} = Schema.summarize_types(workspace)
    end

    test "skips malformed schema files gracefully", %{
      workspace: workspace,
      schemas_dir: schemas_dir
    } do
      Schema.save(workspace, "people", @people_schema)
      File.write!(Path.join(schemas_dir, "broken.json"), "not valid json{{{")

      assert {:ok, summaries} = Schema.summarize_types(workspace)
      assert length(summaries) == 1
      assert hd(summaries).type == "people"
    end
  end
end
