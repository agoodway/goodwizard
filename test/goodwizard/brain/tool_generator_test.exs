defmodule Goodwizard.Brain.ToolGeneratorTest do
  use ExUnit.Case

  alias Goodwizard.Brain.ToolGenerator

  @test_schema %{
    "$schema" => "http://json-schema.org/draft-07/schema#",
    "title" => "Person",
    "type" => "object",
    "required" => ["id", "name"],
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

  setup do
    # Ensure app is running (config tests may stop it)
    Application.ensure_all_started(:goodwizard)

    workspace = Path.join(System.tmp_dir!(), "tool_gen_test_#{:rand.uniform(100_000)}")
    schemas_dir = Path.join([workspace, "brain", "schemas"])
    File.mkdir_p!(schemas_dir)
    on_exit(fn -> File.rm_rf!(workspace) end)

    # Clean up any previously generated modules
    ToolGenerator.purge_all()

    %{workspace: workspace, schemas_dir: schemas_dir}
  end

  describe "generate_for_type/2" do
    test "generates create and update modules for a type", %{
      workspace: workspace,
      schemas_dir: schemas_dir
    } do
      File.write!(Path.join(schemas_dir, "people.json"), Jason.encode!(@test_schema))

      assert {:ok, [create_mod, update_mod]} = ToolGenerator.generate_for_type(workspace, "people")

      assert create_mod |> Module.split() |> List.last() == "CreatePerson"
      assert update_mod |> Module.split() |> List.last() == "UpdatePerson"
    end

    test "generated create module has correct name and schema", %{
      workspace: workspace,
      schemas_dir: schemas_dir
    } do
      File.write!(Path.join(schemas_dir, "people.json"), Jason.encode!(@test_schema))
      {:ok, [create_mod, _]} = ToolGenerator.generate_for_type(workspace, "people")

      assert create_mod.name() == "create_person"
    end

    test "generated update module has correct name", %{
      workspace: workspace,
      schemas_dir: schemas_dir
    } do
      File.write!(Path.join(schemas_dir, "people.json"), Jason.encode!(@test_schema))
      {:ok, [_, update_mod]} = ToolGenerator.generate_for_type(workspace, "people")

      assert update_mod.name() == "update_person"
    end

    test "returns error for non-existent schema", %{workspace: workspace} do
      assert {:error, {:schema_not_found, "nonexistent"}} =
               ToolGenerator.generate_for_type(workspace, "nonexistent")
    end

    test "returns error for corrupt schema file", %{
      workspace: workspace,
      schemas_dir: schemas_dir
    } do
      File.write!(Path.join(schemas_dir, "broken.json"), "not json{{")

      assert {:error, %Jason.DecodeError{}} =
               ToolGenerator.generate_for_type(workspace, "broken")
    end
  end

  describe "generate_all/1" do
    test "generates modules for all schema files", %{
      workspace: workspace,
      schemas_dir: schemas_dir
    } do
      File.write!(Path.join(schemas_dir, "people.json"), Jason.encode!(@test_schema))

      company_schema = %{@test_schema | "title" => "Company"}
      File.write!(Path.join(schemas_dir, "companies.json"), Jason.encode!(company_schema))

      assert {:ok, modules} = ToolGenerator.generate_all(workspace)
      assert length(modules) == 4
    end

    test "returns empty list for missing schemas directory" do
      workspace = Path.join(System.tmp_dir!(), "no_schemas_#{:rand.uniform(100_000)}")
      on_exit(fn -> File.rm_rf!(workspace) end)

      assert {:ok, []} = ToolGenerator.generate_all(workspace)
    end

    test "skips invalid schemas and generates valid ones", %{
      workspace: workspace,
      schemas_dir: schemas_dir
    } do
      File.write!(Path.join(schemas_dir, "people.json"), Jason.encode!(@test_schema))
      File.write!(Path.join(schemas_dir, "broken.json"), "not json{{")

      assert {:ok, modules} = ToolGenerator.generate_all(workspace)
      assert length(modules) == 2
    end
  end

  describe "generated_modules/0" do
    test "returns cached modules after generation", %{
      workspace: workspace,
      schemas_dir: schemas_dir
    } do
      File.write!(Path.join(schemas_dir, "people.json"), Jason.encode!(@test_schema))
      ToolGenerator.generate_all(workspace)

      modules = ToolGenerator.generated_modules()
      assert length(modules) == 2
    end

    test "returns empty list before any generation" do
      ToolGenerator.purge_all()
      assert ToolGenerator.generated_modules() == []
    end
  end

  describe "purge_all/0" do
    test "clears all generated modules", %{
      workspace: workspace,
      schemas_dir: schemas_dir
    } do
      File.write!(Path.join(schemas_dir, "people.json"), Jason.encode!(@test_schema))
      ToolGenerator.generate_all(workspace)

      assert ToolGenerator.generated_modules() != []

      ToolGenerator.purge_all()
      assert ToolGenerator.generated_modules() == []
    end
  end
end
