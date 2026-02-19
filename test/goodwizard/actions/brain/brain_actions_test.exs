defmodule Goodwizard.Actions.Brain.BrainActionsTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Brain.{
    CreateEntity,
    DeleteEntity,
    GetSchema,
    ListEntities,
    ListEntityTypes,
    MigrateEntities,
    ReadEntity,
    SaveSchema,
    UpdateEntity
  }

  alias Goodwizard.Brain.{Entity, Paths, Schema}

  setup do
    workspace = Path.join(System.tmp_dir!(), "brain_actions_test_#{:rand.uniform(100_000)}")
    on_exit(fn -> File.rm_rf!(workspace) end)
    context = %{state: %{workspace: workspace}}
    %{workspace: workspace, context: context}
  end

  defp init_brain(context) do
    {:ok, _} =
      CreateEntity.run(%{entity_type: "people", data: %{"name" => "Init"}, body: ""}, context)

    :ok
  end

  describe "CreateEntity" do
    test "creates entity and returns id, data, body", %{context: context} do
      params = %{entity_type: "people", data: %{"name" => "Alice"}, body: ""}

      assert {:ok, result} = CreateEntity.run(params, context)
      assert is_binary(result.id)
      assert result.data["name"] == "Alice"
      assert result.body == ""
    end

    test "creates entity with body", %{context: context} do
      params = %{entity_type: "people", data: %{"name" => "Bob"}, body: "Some notes."}

      assert {:ok, result} = CreateEntity.run(params, context)
      assert result.body == "Some notes."
    end

    test "returns error for invalid data", %{context: context} do
      params = %{entity_type: "people", data: %{}, body: ""}

      assert {:error, _} = CreateEntity.run(params, context)
    end
  end

  describe "ReadEntity" do
    test "reads a created entity", %{context: context} do
      {:ok, created} =
        CreateEntity.run(
          %{entity_type: "people", data: %{"name" => "Eve"}, body: "Notes."},
          context
        )

      params = %{entity_type: "people", id: created.id}

      assert {:ok, result} = ReadEntity.run(params, context)
      assert result.data["name"] == "Eve"
      assert result.body == "Notes."
    end

    test "returns error for nonexistent entity", %{context: context} do
      init_brain(context)
      assert {:error, _} = ReadEntity.run(%{entity_type: "people", id: "nonexistent"}, context)
    end

    test "strips metadata from returned data", %{context: context} do
      {:ok, created} =
        CreateEntity.run(
          %{
            entity_type: "people",
            data: %{"name" => "Meta", "metadata" => %{"source" => "test"}},
            body: ""
          },
          context
        )

      assert {:ok, result} = ReadEntity.run(%{entity_type: "people", id: created.id}, context)
      refute Map.has_key?(result.data, "metadata")
      assert result.data["name"] == "Meta"
    end
  end

  describe "UpdateEntity" do
    test "updates entity data", %{context: context} do
      {:ok, created} =
        CreateEntity.run(%{entity_type: "people", data: %{"name" => "Frank"}, body: ""}, context)

      params = %{entity_type: "people", id: created.id, data: %{"name" => "Frank Updated"}}

      assert {:ok, result} = UpdateEntity.run(params, context)
      assert result.data["name"] == "Frank Updated"
    end

    test "updates body when provided", %{context: context} do
      {:ok, created} =
        CreateEntity.run(
          %{entity_type: "people", data: %{"name" => "Grace"}, body: "Old."},
          context
        )

      params = %{entity_type: "people", id: created.id, data: %{}, body: "New notes."}

      assert {:ok, result} = UpdateEntity.run(params, context)
      assert result.body == "New notes."
    end

    test "preserves body when not provided", %{context: context} do
      {:ok, created} =
        CreateEntity.run(
          %{entity_type: "people", data: %{"name" => "Hank"}, body: "Keep me."},
          context
        )

      params = %{entity_type: "people", id: created.id, data: %{"name" => "Hank Updated"}}

      assert {:ok, result} = UpdateEntity.run(params, context)
      assert result.body == "Keep me."
    end

    test "returns error for nonexistent entity", %{context: context} do
      init_brain(context)

      assert {:error, _} =
               UpdateEntity.run(
                 %{entity_type: "people", id: "nonexistent", data: %{"name" => "Ghost"}},
                 context
               )
    end
  end

  describe "DeleteEntity" do
    test "deletes an existing entity", %{context: context} do
      {:ok, created} =
        CreateEntity.run(%{entity_type: "people", data: %{"name" => "Jack"}, body: ""}, context)

      assert {:ok, %{message: msg}} =
               DeleteEntity.run(%{entity_type: "people", id: created.id}, context)

      assert msg =~ "deleted"

      assert {:error, _} = ReadEntity.run(%{entity_type: "people", id: created.id}, context)
    end

    test "returns error for nonexistent entity", %{context: context} do
      init_brain(context)
      assert {:error, _} = DeleteEntity.run(%{entity_type: "people", id: "nonexistent"}, context)
    end
  end

  describe "ListEntities" do
    test "lists all entities of a type", %{context: context} do
      CreateEntity.run(%{entity_type: "people", data: %{"name" => "Alice"}, body: ""}, context)
      CreateEntity.run(%{entity_type: "people", data: %{"name" => "Bob"}, body: ""}, context)

      assert {:ok, result} = ListEntities.run(%{entity_type: "people"}, context)
      assert length(result.entities) == 2

      names = Enum.map(result.entities, & &1.data["name"]) |> Enum.sort()
      assert names == ["Alice", "Bob"]
    end

    test "returns empty list when no entities exist", %{context: context} do
      assert {:ok, %{entities: []}} =
               ListEntities.run(%{entity_type: "people"}, context)
    end

    test "strips metadata from returned entity data", %{context: context} do
      CreateEntity.run(
        %{
          entity_type: "people",
          data: %{"name" => "Alice", "metadata" => %{"source" => "csv"}},
          body: ""
        },
        context
      )

      CreateEntity.run(
        %{entity_type: "people", data: %{"name" => "Bob"}, body: ""},
        context
      )

      assert {:ok, result} = ListEntities.run(%{entity_type: "people"}, context)

      for item <- result.entities do
        refute Map.has_key?(item.data, "metadata"),
               "Expected metadata to be stripped from #{item.data["name"]}"
      end
    end
  end

  describe "GetSchema" do
    test "returns schema for a seeded type", %{context: context} do
      init_brain(context)

      assert {:ok, %{schema: schema}} = GetSchema.run(%{entity_type: "people"}, context)
      assert is_map(schema)
      assert schema["type"] == "object"
    end

    test "returns error for nonexistent type", %{context: context} do
      init_brain(context)
      assert {:error, _} = GetSchema.run(%{entity_type: "nonexistent_type"}, context)
    end
  end

  describe "SaveSchema" do
    test "saves a new schema", %{context: context} do
      init_brain(context)

      schema = %{
        "type" => "object",
        "properties" => %{
          "title" => %{"type" => "string"}
        },
        "required" => ["title"]
      }

      assert {:ok, %{message: msg}} =
               SaveSchema.run(%{entity_type: "projects", schema: schema}, context)

      assert msg =~ "projects"

      # Verify it was saved by reading it back
      assert {:ok, %{schema: loaded}} = GetSchema.run(%{entity_type: "projects"}, context)
      assert loaded["properties"]["title"]["type"] == "string"
    end

    test "rejects invalid JSON Schema", %{context: context} do
      init_brain(context)

      invalid_schema = %{"type" => "not_a_real_type", "$ref" => "#/definitions/missing"}

      assert {:error, msg} =
               SaveSchema.run(%{entity_type: "bad", schema: invalid_schema}, context)

      assert msg =~ "Invalid JSON Schema"
    end

    test "requires migration when updating an existing schema", %{context: context} do
      init_brain(context)

      schema_v1 = %{
        "type" => "object",
        "version" => 1,
        "properties" => %{"name" => %{"type" => "string"}},
        "required" => ["name"]
      }

      schema_v2 = %{
        "type" => "object",
        "version" => 2,
        "properties" => %{
          "name" => %{"type" => "string"},
          "status" => %{"type" => "string"}
        },
        "required" => ["name", "status"]
      }

      assert {:ok, _} = SaveSchema.run(%{entity_type: "projects", schema: schema_v1}, context)

      assert {:error, message} =
               SaveSchema.run(%{entity_type: "projects", schema: schema_v2}, context)

      assert message =~ "Migration definition is required"
    end

    test "accepts migration definition when updating an existing schema", %{
      context: context,
      workspace: workspace
    } do
      init_brain(context)

      schema_v1 = %{
        "type" => "object",
        "version" => 1,
        "properties" => %{"name" => %{"type" => "string"}},
        "required" => ["name"]
      }

      schema_v2 = %{
        "type" => "object",
        "version" => 2,
        "properties" => %{
          "name" => %{"type" => "string"},
          "status" => %{"type" => "string"}
        },
        "required" => ["name", "status"]
      }

      migration = %{
        "from_version" => 1,
        "to_version" => 2,
        "operations" => [
          %{"op" => "add_field", "field" => "status", "default" => "pending"}
        ]
      }

      assert {:ok, _} = SaveSchema.run(%{entity_type: "projects", schema: schema_v1}, context)

      assert {:ok, %{message: message}} =
               SaveSchema.run(
                 %{entity_type: "projects", schema: schema_v2, migration: migration},
                 context
               )

      assert message =~ "projects"

      assert {:ok, migration_path} = Paths.migration_path(workspace, "projects", 1, 2)
      assert File.exists?(migration_path)
    end
  end

  describe "MigrateEntities" do
    test "runs dry-run migration and returns changes without writing", %{
      context: context,
      workspace: workspace
    } do
      schema_v2 = %{
        "$schema" => "http://json-schema.org/draft-07/schema#",
        "title" => "ProjectV2",
        "version" => 2,
        "type" => "object",
        "required" => ["id", "name", "status", "created_at", "updated_at"],
        "properties" => %{
          "id" => %{"type" => "string"},
          "name" => %{"type" => "string"},
          "status" => %{"type" => "string"},
          "created_at" => %{"type" => "string"},
          "updated_at" => %{"type" => "string"}
        },
        "additionalProperties" => false
      }

      migration = %{
        "from_version" => 1,
        "to_version" => 2,
        "operations" => [
          %{"op" => "rename_field", "from" => "full_name", "to" => "name"},
          %{"op" => "set_default", "field" => "status", "value" => "pending"},
          %{"op" => "remove_field", "field" => "legacy"}
        ]
      }

      assert :ok = Schema.save(workspace, "projects", schema_v2)
      assert :ok = File.mkdir_p(Paths.schema_migrations_dir(workspace))
      {:ok, migration_path} = Paths.migration_path(workspace, "projects", 1, 2)
      assert :ok = File.write(migration_path, Jason.encode!(migration))

      ts = "2026-01-01T00:00:00Z"

      write_entity!(
        workspace,
        "projects",
        "p-1",
        %{
          "id" => "p-1",
          "full_name" => "Project One",
          "legacy" => "deprecated",
          "created_at" => ts,
          "updated_at" => ts
        }
      )

      before = read_entity_data!(workspace, "projects", "p-1")

      assert {:ok, result} =
               MigrateEntities.run(
                 %{entity_type: "projects", from_version: 1, to_version: 2, dry_run: true},
                 context
               )

      assert result.total == 1
      assert result.migrated == 1
      assert length(result.changes) == 1

      after_dry_run = read_entity_data!(workspace, "projects", "p-1")
      assert after_dry_run == before
    end

    test "executes migration and writes entity updates", %{context: context, workspace: workspace} do
      schema_v2 = %{
        "$schema" => "http://json-schema.org/draft-07/schema#",
        "title" => "ProjectV2",
        "version" => 2,
        "type" => "object",
        "required" => ["id", "name", "status", "created_at", "updated_at"],
        "properties" => %{
          "id" => %{"type" => "string"},
          "name" => %{"type" => "string"},
          "status" => %{"type" => "string"},
          "created_at" => %{"type" => "string"},
          "updated_at" => %{"type" => "string"}
        },
        "additionalProperties" => false
      }

      migration = %{
        "from_version" => 1,
        "to_version" => 2,
        "operations" => [
          %{"op" => "rename_field", "from" => "full_name", "to" => "name"},
          %{"op" => "set_default", "field" => "status", "value" => "pending"},
          %{"op" => "remove_field", "field" => "legacy"}
        ]
      }

      assert :ok = Schema.save(workspace, "projects", schema_v2)
      assert :ok = File.mkdir_p(Paths.schema_migrations_dir(workspace))
      {:ok, migration_path} = Paths.migration_path(workspace, "projects", 1, 2)
      assert :ok = File.write(migration_path, Jason.encode!(migration))

      ts = "2026-01-01T00:00:00Z"

      write_entity!(
        workspace,
        "projects",
        "p-2",
        %{
          "id" => "p-2",
          "full_name" => "Project Two",
          "legacy" => "deprecated",
          "created_at" => ts,
          "updated_at" => ts
        }
      )

      assert {:ok, result} =
               MigrateEntities.run(
                 %{entity_type: "projects", from_version: 1, to_version: 2},
                 context
               )

      assert result.total == 1
      assert result.migrated == 1

      migrated = read_entity_data!(workspace, "projects", "p-2")
      assert migrated["name"] == "Project Two"
      assert migrated["status"] == "pending"
      refute Map.has_key?(migrated, "full_name")
      refute Map.has_key?(migrated, "legacy")
      assert migrated["updated_at"] != ts
    end
  end

  describe "ListEntityTypes" do
    test "lists available entity types", %{context: context} do
      init_brain(context)

      assert {:ok, result} = ListEntityTypes.run(%{}, context)
      assert is_list(result.types)
      assert result.types != []
      assert "people" in result.types
    end

    test "returns empty list for uninitialized workspace", %{context: context} do
      assert {:ok, %{types: []}} = ListEntityTypes.run(%{}, context)
    end
  end

  describe "workspace resolution" do
    test "falls back to current directory when workspace not in context" do
      workspace = Path.join(System.tmp_dir!(), "brain_no_ctx_#{:rand.uniform(100_000)}")
      on_exit(fn -> File.rm_rf!(workspace) end)

      empty_context = %{state: %{}}

      # Just verify it doesn't crash
      result = ListEntityTypes.run(%{}, empty_context)
      assert {:ok, _} = result
    end
  end

  describe "security: path traversal and injection" do
    test "rejects entity_type with path traversal", %{context: context} do
      init_brain(context)

      assert {:error, msg} =
               CreateEntity.run(
                 %{entity_type: "../etc", data: %{"name" => "Evil"}, body: ""},
                 context
               )

      assert is_binary(msg)
    end

    test "rejects entity_type with null bytes", %{context: context} do
      init_brain(context)

      assert {:error, msg} =
               CreateEntity.run(
                 %{entity_type: "people\0evil", data: %{"name" => "Evil"}, body: ""},
                 context
               )

      assert is_binary(msg)
    end

    test "rejects id with path traversal", %{context: context} do
      init_brain(context)

      assert {:error, msg} =
               ReadEntity.run(%{entity_type: "people", id: "../../etc/passwd"}, context)

      assert is_binary(msg)
    end

    test "rejects empty entity_type", %{context: context} do
      assert {:error, msg} =
               CreateEntity.run(%{entity_type: "", data: %{"name" => "Evil"}, body: ""}, context)

      assert is_binary(msg)
    end
  end

  describe "concurrent access" do
    test "concurrent updates return at least one success", %{context: context} do
      {:ok, created} =
        CreateEntity.run(%{entity_type: "people", data: %{"name" => "Target"}, body: ""}, context)

      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            UpdateEntity.run(
              %{entity_type: "people", id: created.id, data: %{"name" => "Updated #{i}"}},
              context
            )
          end)
        end

      results = Enum.map(tasks, &Task.await/1)
      successes = Enum.filter(results, &match?({:ok, _}, &1))
      assert successes != []
    end

    test "concurrent creates produce unique IDs", %{context: context} do
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            CreateEntity.run(
              %{entity_type: "people", data: %{"name" => "Person #{i}"}, body: ""},
              context
            )
          end)
        end

      results = Enum.map(tasks, &Task.await/1)
      ids = for {:ok, result} <- results, do: result.id
      assert length(ids) == length(Enum.uniq(ids))
    end
  end

  defp write_entity!(workspace, entity_type, id, data) do
    {:ok, type_dir} = Paths.entity_type_dir(workspace, entity_type)
    :ok = File.mkdir_p(type_dir)
    {:ok, path} = Paths.entity_path(workspace, entity_type, id)
    :ok = File.write(path, Entity.serialize(data, ""))
  end

  defp read_entity_data!(workspace, entity_type, id) do
    {:ok, path} = Paths.entity_path(workspace, entity_type, id)
    {:ok, content} = File.read(path)
    {:ok, {data, _body}} = Entity.parse(content)
    data
  end
end
