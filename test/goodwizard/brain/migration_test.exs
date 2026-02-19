defmodule Goodwizard.Brain.MigrationTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Brain.{Entity, Migration, Paths, Schema}

  @schema_v2 %{
    "$schema" => "http://json-schema.org/draft-07/schema#",
    "title" => "PersonV2",
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

  @migration_v1_to_v2 %{
    "from_version" => 1,
    "to_version" => 2,
    "operations" => [
      %{"op" => "rename_field", "from" => "full_name", "to" => "name"},
      %{"op" => "set_default", "field" => "status", "value" => "pending"},
      %{"op" => "remove_field", "field" => "legacy"}
    ]
  }

  setup do
    workspace = Path.join(System.tmp_dir!(), "brain_migration_test_#{:rand.uniform(100_000)}")
    on_exit(fn -> File.rm_rf!(workspace) end)
    %{workspace: workspace}
  end

  describe "load/4" do
    test "returns missing file error when migration file does not exist", %{workspace: workspace} do
      assert {:error, :enoent} = Migration.load(workspace, "people", 1, 2)
    end

    test "loads a stored migration definition", %{workspace: workspace} do
      assert :ok = File.mkdir_p(Paths.schema_migrations_dir(workspace))
      {:ok, path} = Paths.migration_path(workspace, "people", 1, 2)
      assert :ok = File.write(path, Jason.encode!(@migration_v1_to_v2))

      assert {:ok, loaded} = Migration.load(workspace, "people", 1, 2)
      assert loaded["from_version"] == 1
      assert loaded["to_version"] == 2
      assert is_list(loaded["operations"])
    end
  end

  describe "apply_operations/2" do
    test "add_field adds only when field is absent" do
      data = %{"id" => "1", "name" => "Alice"}
      ops = [%{"op" => "add_field", "field" => "status", "default" => "pending"}]

      assert {:ok, updated} = Migration.apply_operations(data, ops)
      assert updated["status"] == "pending"

      assert {:ok, unchanged} = Migration.apply_operations(updated, ops)
      assert unchanged["status"] == "pending"
    end

    test "add_field preserves explicit false defaults from string keys" do
      data = %{"id" => "1"}

      ops = [
        %{
          "op" => "add_field",
          "field" => "is_active",
          "default" => false,
          default: true
        }
      ]

      assert {:ok, updated} = Migration.apply_operations(data, ops)
      assert updated["is_active"] == false
    end

    test "rename_field preserves value under new key" do
      data = %{"full_name" => "Alice"}
      ops = [%{"op" => "rename_field", "from" => "full_name", "to" => "name"}]

      assert {:ok, updated} = Migration.apply_operations(data, ops)
      refute Map.has_key?(updated, "full_name")
      assert updated["name"] == "Alice"
    end

    test "remove_field drops existing key" do
      data = %{"id" => "1", "legacy" => "old"}
      ops = [%{"op" => "remove_field", "field" => "legacy"}]

      assert {:ok, updated} = Migration.apply_operations(data, ops)
      refute Map.has_key?(updated, "legacy")
    end

    test "set_default sets value only when missing" do
      data = %{"id" => "1"}
      ops = [%{"op" => "set_default", "field" => "status", "value" => "pending"}]

      assert {:ok, updated} = Migration.apply_operations(data, ops)
      assert updated["status"] == "pending"

      assert {:ok, unchanged} = Migration.apply_operations(%{"status" => "active"}, ops)
      assert unchanged["status"] == "active"
    end

    test "set_default preserves explicit false values from atom keys" do
      data = %{"id" => "1"}
      ops = [%{op: "set_default", field: "is_active", value: false}]

      assert {:ok, updated} = Migration.apply_operations(data, ops)
      assert updated["is_active"] == false
    end

    test "applies operations in order" do
      data = %{"notes_ref" => "N-1"}

      ops = [
        %{"op" => "rename_field", "from" => "notes_ref", "to" => "notes"},
        %{"op" => "set_default", "field" => "notes", "value" => "N-2"}
      ]

      assert {:ok, updated} = Migration.apply_operations(data, ops)
      assert updated["notes"] == "N-1"
    end
  end

  describe "execute/3 and dry_run/3" do
    test "execute migrates valid candidates, skips already-valid entities, and reports errors", %{
      workspace: workspace
    } do
      assert :ok = Schema.save(workspace, "people", @schema_v2)

      ts = "2026-01-01T00:00:00Z"

      write_entity!(
        workspace,
        "people",
        "needs_migration",
        %{
          "id" => "needs_migration",
          "full_name" => "Alice",
          "legacy" => "deprecated",
          "created_at" => ts,
          "updated_at" => ts
        }
      )

      write_entity!(
        workspace,
        "people",
        "already_valid",
        %{
          "id" => "already_valid",
          "name" => "Bob",
          "status" => "active",
          "created_at" => ts,
          "updated_at" => ts
        }
      )

      write_entity!(
        workspace,
        "people",
        "will_fail_validation",
        %{
          "id" => "will_fail_validation",
          "legacy" => "deprecated",
          "created_at" => ts,
          "updated_at" => ts
        }
      )

      assert {:ok, summary} = Migration.execute(workspace, "people", @migration_v1_to_v2)
      assert summary.total == 3
      assert summary.migrated == 1
      assert summary.skipped == 1
      assert length(summary.errors) == 1

      assert [%{id: "will_fail_validation"}] = summary.errors

      migrated_data = read_entity_data!(workspace, "people", "needs_migration")
      assert migrated_data["name"] == "Alice"
      assert migrated_data["status"] == "pending"
      refute Map.has_key?(migrated_data, "full_name")
      refute Map.has_key?(migrated_data, "legacy")
      assert migrated_data["updated_at"] != ts
    end

    test "dry_run reports diffs without writing files", %{workspace: workspace} do
      assert :ok = Schema.save(workspace, "people", @schema_v2)

      ts = "2026-01-01T00:00:00Z"

      write_entity!(
        workspace,
        "people",
        "dry_run_target",
        %{
          "id" => "dry_run_target",
          "full_name" => "Carol",
          "legacy" => "deprecated",
          "created_at" => ts,
          "updated_at" => ts
        }
      )

      before = read_entity_data!(workspace, "people", "dry_run_target")

      assert {:ok, summary} = Migration.dry_run(workspace, "people", @migration_v1_to_v2)
      assert summary.total == 1
      assert summary.migrated == 1
      assert summary.skipped == 0
      assert summary.errors == []
      assert length(summary.changes) == 1

      [change] = summary.changes
      assert change.id == "dry_run_target"
      assert change.before["full_name"] == "Carol"
      assert change.after["name"] == "Carol"

      after_dry_run = read_entity_data!(workspace, "people", "dry_run_target")
      assert after_dry_run == before
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
