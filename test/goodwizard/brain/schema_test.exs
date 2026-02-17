defmodule Goodwizard.Brain.SchemaTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Brain.Schema

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
