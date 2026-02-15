defmodule Goodwizard.Brain.SeedsTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Brain.{Schema, Seeds}

  @expected_types ~w(companies events notes people places tasklists tasks)

  setup do
    workspace = Path.join(System.tmp_dir!(), "brain_seeds_test_#{:rand.uniform(100_000)}")
    schemas_dir = Path.join([workspace, "brain", "schemas"])
    File.mkdir_p!(schemas_dir)
    on_exit(fn -> File.rm_rf!(workspace) end)
    %{workspace: workspace, schemas_dir: schemas_dir}
  end

  describe "seed/1" do
    test "creates all 7 schema files", %{workspace: workspace} do
      assert {:ok, seeded} = Seeds.seed(workspace)
      assert length(seeded) == 7
      assert Enum.sort(seeded) == @expected_types
    end

    test "schema files are valid JSON with correct structure", %{
      workspace: workspace,
      schemas_dir: schemas_dir
    } do
      Seeds.seed(workspace)

      for type <- @expected_types do
        path = Path.join(schemas_dir, "#{type}.json")
        assert File.exists?(path), "Missing schema file: #{type}.json"

        content = File.read!(path)
        assert {:ok, schema} = Jason.decode(content)
        assert schema["$schema"] == "http://json-schema.org/draft-07/schema#"
        assert schema["version"] == 1
        assert schema["type"] == "object"
        assert is_list(schema["required"])
        assert "id" in schema["required"]
        assert schema["additionalProperties"] == false
      end
    end

    test "schemas are resolvable by ex_json_schema", %{workspace: workspace} do
      Seeds.seed(workspace)

      for type <- @expected_types do
        assert {:ok, resolved} = Schema.load(workspace, type)
        assert %ExJsonSchema.Schema.Root{} = resolved
      end
    end

    test "is idempotent — skips existing schemas", %{workspace: workspace} do
      {:ok, first_seeded} = Seeds.seed(workspace)
      assert length(first_seeded) == 7

      {:ok, second_seeded} = Seeds.seed(workspace)
      assert second_seeded == []
    end

    test "only seeds missing schemas", %{workspace: workspace, schemas_dir: schemas_dir} do
      # Pre-create one schema
      File.write!(Path.join(schemas_dir, "people.json"), Jason.encode!(%{"existing" => true}))

      {:ok, seeded} = Seeds.seed(workspace)
      assert "people" not in seeded
      assert length(seeded) == 6

      # Verify people.json was not overwritten
      content = File.read!(Path.join(schemas_dir, "people.json"))
      assert {:ok, %{"existing" => true}} = Jason.decode(content)
    end

    test "returns error when schemas directory is unwritable", %{
      workspace: workspace,
      schemas_dir: schemas_dir
    } do
      # Make schemas dir read-only to force write failure
      File.chmod!(schemas_dir, 0o444)
      on_exit(fn -> File.chmod(schemas_dir, 0o755) end)

      assert {:error, _reason} = Seeds.seed(workspace)
    end
  end

  describe "schema_for/1" do
    test "returns a map for each entity type" do
      for type <- Seeds.entity_types() do
        schema = Seeds.schema_for(type)
        assert is_map(schema)
        assert schema["version"] == 1
      end
    end

    test "people schema has correct required fields" do
      schema = Seeds.schema_for("people")
      assert schema["required"] == ["id", "name"]
      assert Map.has_key?(schema["properties"], "email")
      assert Map.has_key?(schema["properties"], "company")
    end

    test "events schema requires date" do
      schema = Seeds.schema_for("events")
      assert "date" in schema["required"]
    end

    test "tasks schema has status and priority enums" do
      schema = Seeds.schema_for("tasks")

      assert schema["properties"]["status"]["enum"] == [
               "pending",
               "in_progress",
               "done",
               "cancelled"
             ]

      assert schema["properties"]["priority"]["enum"] == ["low", "medium", "high"]
    end

    test "tasklists schema has status enum and tasks entity_ref_list" do
      schema = Seeds.schema_for("tasklists")
      assert schema["required"] == ["id", "title"]

      assert schema["properties"]["status"]["enum"] == ["active", "completed", "archived"]

      tasks = schema["properties"]["tasks"]
      assert tasks["type"] == "array"
      assert tasks["items"]["pattern"] == "^tasks/[a-z0-9]{8,64}$"
    end

    test "notes schema has polymorphic related_to references" do
      schema = Seeds.schema_for("notes")
      related = schema["properties"]["related_to"]
      assert related["items"]["pattern"] == "^[a-z_]+/[a-z0-9]{8,64}$"
    end
  end

  describe "entity_types/0" do
    test "returns 7 types" do
      assert length(Seeds.entity_types()) == 7
    end
  end
end

defmodule Goodwizard.BrainTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Brain
  alias Goodwizard.Brain.{Id, Paths, Schema}

  setup do
    workspace = Path.join(System.tmp_dir!(), "brain_init_test_#{:rand.uniform(100_000)}")
    on_exit(fn -> File.rm_rf!(workspace) end)
    %{workspace: workspace}
  end

  describe "ensure_initialized/1" do
    test "creates brain directory structure and seeds schemas", %{workspace: workspace} do
      refute File.exists?(Path.join(workspace, "brain"))

      assert {:ok, seeded} = Brain.ensure_initialized(workspace)
      assert length(seeded) == 7

      assert File.dir?(Path.join(workspace, "brain"))
      assert File.dir?(Path.join([workspace, "brain", "schemas"]))
    end

    test "is idempotent — second call returns empty list", %{workspace: workspace} do
      {:ok, first} = Brain.ensure_initialized(workspace)
      assert length(first) == 7

      {:ok, second} = Brain.ensure_initialized(workspace)
      assert second == []
    end

    test "does not re-seed when schemas already exist", %{workspace: workspace} do
      Brain.ensure_initialized(workspace)

      # Modify a schema to verify it's not overwritten
      {:ok, path} = Paths.schema_path(workspace, "people")
      File.write!(path, Jason.encode!(%{"custom" => true}))

      {:ok, []} = Brain.ensure_initialized(workspace)

      # Verify the modified schema was preserved
      content = File.read!(path)
      assert {:ok, %{"custom" => true}} = Jason.decode(content)
    end
  end

  describe "end-to-end workflow" do
    test "initialize -> generate ID -> load schema -> validate", %{workspace: workspace} do
      # 1. Initialize brain (seeds schemas)
      assert {:ok, seeded} = Brain.ensure_initialized(workspace)
      assert length(seeded) == 7

      # 2. Generate an ID
      assert {:ok, id} = Id.generate(workspace)
      assert Id.valid?(id)

      # 3. Load a seeded schema
      assert {:ok, resolved} = Schema.load(workspace, "people")

      # 4. Validate data against schema
      valid_data = %{"id" => id, "name" => "Alice"}
      assert :ok = Schema.validate(resolved, valid_data)

      # 5. Invalid data should fail
      invalid_data = %{"id" => "AB", "name" => 123}
      assert {:error, _} = Schema.validate(resolved, invalid_data)
    end
  end
end
