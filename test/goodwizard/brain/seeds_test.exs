defmodule Goodwizard.Brain.SeedsTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Brain.{Schema, Seeds}

  @expected_types ~w(companies events notes people places tasklists tasks webpages)

  setup do
    workspace = Path.join(System.tmp_dir!(), "brain_seeds_test_#{:rand.uniform(100_000)}")
    schemas_dir = Path.join([workspace, "brain", "schemas"])
    File.mkdir_p!(schemas_dir)
    on_exit(fn -> File.rm_rf!(workspace) end)
    %{workspace: workspace, schemas_dir: schemas_dir}
  end

  describe "seed/1" do
    test "creates all schema files", %{workspace: workspace} do
      assert {:ok, seeded} = Seeds.seed(workspace)
      assert length(seeded) == length(@expected_types)
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
        assert is_integer(schema["version"])
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
      assert length(first_seeded) == length(@expected_types)

      {:ok, second_seeded} = Seeds.seed(workspace)
      assert second_seeded == []
    end

    test "only seeds missing schemas", %{workspace: workspace, schemas_dir: schemas_dir} do
      # Pre-create one schema
      File.write!(Path.join(schemas_dir, "people.json"), Jason.encode!(%{"existing" => true}))

      {:ok, seeded} = Seeds.seed(workspace)
      assert "people" not in seeded
      assert length(seeded) == length(@expected_types) - 1

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
        assert is_integer(schema["version"])
      end
    end

    test "people schema has correct required fields and multi-value contact fields" do
      schema = Seeds.schema_for("people")
      assert schema["required"] == ["id", "name", "metadata"]
      assert schema["version"] == 2
      assert Map.has_key?(schema["properties"], "emails")
      assert Map.has_key?(schema["properties"], "phones")
      assert Map.has_key?(schema["properties"], "addresses")
      assert Map.has_key?(schema["properties"], "socials")
      assert Map.has_key?(schema["properties"], "company")
      refute Map.has_key?(schema["properties"], "email")
      refute Map.has_key?(schema["properties"], "phone")
    end

    test "companies schema has multi-value contact fields" do
      schema = Seeds.schema_for("companies")
      assert schema["version"] == 2
      assert Map.has_key?(schema["properties"], "emails")
      assert Map.has_key?(schema["properties"], "phones")
      assert Map.has_key?(schema["properties"], "addresses")
      assert Map.has_key?(schema["properties"], "socials")
      refute Map.has_key?(schema["properties"], "location")
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
      assert schema["required"] == ["id", "title", "metadata"]

      assert schema["properties"]["status"]["enum"] == ["active", "completed", "archived"]

      tasks = schema["properties"]["tasks"]
      assert tasks["type"] == "array"

      assert tasks["items"]["pattern"] ==
               "^tasks/[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
    end

    test "notes schema has polymorphic related_to references" do
      schema = Seeds.schema_for("notes")
      related = schema["properties"]["related_to"]

      assert related["items"]["pattern"] ==
               "^[a-z_]+/[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
    end

    test "webpages schema has correct required fields and url format" do
      schema = Seeds.schema_for("webpages")
      assert schema["required"] == ["id", "title", "url", "metadata"]
      assert schema["properties"]["url"]["format"] == "uri"
      assert schema["properties"]["url"]["pattern"] == "^https?://"
      assert schema["properties"]["url"]["maxLength"] == 2048
      assert Map.has_key?(schema["properties"], "description")
      assert schema["properties"]["description"]["maxLength"] == 10_000
    end

    test "webpages schema does not include a webpages self-reference" do
      schema = Seeds.schema_for("webpages")
      refute Map.has_key?(schema["properties"], "webpages")
    end

    test "all seed schemas include metadata in properties and required" do
      for type <- Seeds.entity_types() do
        schema = Seeds.schema_for(type)

        assert Map.has_key?(schema["properties"], "metadata"),
               "Expected #{type} schema to have metadata property"

        metadata = schema["properties"]["metadata"]
        assert metadata["type"] == "object"
        assert metadata["additionalProperties"] == %{"type" => "string", "maxLength" => 1000}
        assert metadata["maxProperties"] == 50
        assert metadata["propertyNames"]["pattern"] == "^[a-zA-Z0-9_.-]{1,64}$"

        assert "metadata" in schema["required"],
               "Expected #{type} schema to have metadata in required"
      end
    end

    test "other entity schemas include webpages ref_list property" do
      for type <- Seeds.entity_types(), type != "webpages" do
        schema = Seeds.schema_for(type)

        assert Map.has_key?(schema["properties"], "webpages"),
               "Expected #{type} schema to have webpages property"

        webpages = schema["properties"]["webpages"]
        assert webpages["type"] == "array"
        assert webpages["items"]["pattern"] =~ "^webpages/"
      end
    end
  end

  describe "entity_types/0" do
    test "returns all expected types" do
      assert length(Seeds.entity_types()) == length(@expected_types)
    end
  end

  describe "seeded_type?/1" do
    test "returns true for all seeded entity types" do
      for type <- Seeds.entity_types() do
        assert Seeds.seeded_type?(type), "Expected #{type} to be treated as seeded"
      end
    end

    test "returns false for non-seeded values" do
      refute Seeds.seeded_type?("widgets")
      refute Seeds.seeded_type?(nil)
    end
  end
end

defmodule Goodwizard.BrainTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Brain
  alias Goodwizard.Brain.{Id, Paths, Schema, Seeds}

  setup do
    workspace = Path.join(System.tmp_dir!(), "brain_init_test_#{:rand.uniform(100_000)}")
    on_exit(fn -> File.rm_rf!(workspace) end)
    %{workspace: workspace}
  end

  describe "ensure_initialized/1" do
    test "creates brain directory structure and seeds schemas", %{workspace: workspace} do
      refute File.exists?(Path.join(workspace, "brain"))

      assert {:ok, seeded} = Brain.ensure_initialized(workspace)
      assert length(seeded) == length(Seeds.entity_types())

      assert File.dir?(Path.join(workspace, "brain"))
      assert File.dir?(Path.join([workspace, "brain", "schemas"]))
    end

    test "is idempotent — second call returns empty list", %{workspace: workspace} do
      {:ok, first} = Brain.ensure_initialized(workspace)
      assert length(first) == length(Seeds.entity_types())

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
      assert length(seeded) == length(Seeds.entity_types())

      # 2. Generate an ID
      assert {:ok, id} = Id.generate()
      assert Id.valid?(id)

      # 3. Load a seeded schema
      assert {:ok, resolved} = Schema.load(workspace, "people")

      # 4. Validate data against schema
      valid_data = %{"id" => id, "name" => "Alice", "metadata" => %{}}
      assert :ok = Schema.validate(resolved, valid_data)

      # 5. Invalid data should fail
      invalid_data = %{"id" => "AB", "name" => 123}
      assert {:error, _} = Schema.validate(resolved, invalid_data)
    end
  end
end
