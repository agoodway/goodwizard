defmodule Goodwizard.BrainCrudTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Brain

  setup do
    workspace = Path.join(System.tmp_dir!(), "brain_crud_test_#{:rand.uniform(100_000)}")
    on_exit(fn -> File.rm_rf!(workspace) end)
    %{workspace: workspace}
  end

  describe "create/4" do
    test "creates entity and returns id, data, body", %{workspace: workspace} do
      assert {:ok, {id, data, body}} = Brain.create(workspace, "people", %{"name" => "Alice"})

      assert is_binary(id)
      assert data["id"] == id
      assert data["name"] == "Alice"
      assert data["created_at"]
      assert data["updated_at"]
      assert body == ""
    end

    test "creates entity with body", %{workspace: workspace} do
      assert {:ok, {_id, _data, body}} =
               Brain.create(workspace, "people", %{"name" => "Bob"}, "Met at the conference.")

      assert body == "Met at the conference."
    end

    test "writes entity file to disk", %{workspace: workspace} do
      {:ok, {id, _data, _body}} = Brain.create(workspace, "people", %{"name" => "Charlie"})

      {:ok, path} = Goodwizard.Brain.Paths.entity_path(workspace, "people", id)
      assert File.exists?(path)

      content = File.read!(path)
      assert String.contains?(content, "name: Charlie")
    end

    test "auto-initializes brain on first create", %{workspace: workspace} do
      refute File.exists?(Path.join(workspace, "brain"))

      {:ok, _} = Brain.create(workspace, "people", %{"name" => "Dave"})

      assert File.dir?(Path.join([workspace, "brain", "schemas"]))
    end

    test "returns schema validation error for invalid data", %{workspace: workspace} do
      # Missing required "name" field
      assert {:error, _} = Brain.create(workspace, "people", %{})
    end

    test "returns schema validation error for wrong types", %{workspace: workspace} do
      assert {:error, _} = Brain.create(workspace, "people", %{"name" => 123})
    end
  end

  describe "read/3" do
    test "reads back a created entity", %{workspace: workspace} do
      {:ok, {id, _data, _body}} =
        Brain.create(workspace, "people", %{"name" => "Eve"}, "Some notes.")

      assert {:ok, {data, body}} = Brain.read(workspace, "people", id)
      assert data["name"] == "Eve"
      assert data["id"] == id
      assert body == "Some notes."
    end

    test "returns not_found for nonexistent entity", %{workspace: workspace} do
      Brain.ensure_initialized(workspace)
      assert {:error, :not_found} = Brain.read(workspace, "people", "nonexistent")
    end
  end

  describe "update/5" do
    test "merges new data with existing", %{workspace: workspace} do
      {:ok, {id, original_data, _body}} =
        Brain.create(workspace, "people", %{"name" => "Frank", "email" => "frank@example.com"})

      {:ok, {updated_data, _body}} =
        Brain.update(workspace, "people", id, %{"email" => "new@example.com"})

      assert updated_data["name"] == "Frank"
      assert updated_data["email"] == "new@example.com"
      assert updated_data["updated_at"] != original_data["updated_at"]
    end

    test "preserves body when body is nil", %{workspace: workspace} do
      {:ok, {id, _data, _body}} =
        Brain.create(workspace, "people", %{"name" => "Grace"}, "Original notes.")

      {:ok, {_data, body}} = Brain.update(workspace, "people", id, %{"name" => "Grace Updated"})
      assert body == "Original notes."
    end

    test "updates body when provided", %{workspace: workspace} do
      {:ok, {id, _data, _body}} =
        Brain.create(workspace, "people", %{"name" => "Hank"}, "Old notes.")

      {:ok, {_data, body}} =
        Brain.update(workspace, "people", id, %{"name" => "Hank"}, "New notes.")

      assert body == "New notes."
    end

    test "returns not_found for nonexistent entity", %{workspace: workspace} do
      Brain.ensure_initialized(workspace)
      assert {:error, :not_found} = Brain.update(workspace, "people", "nonexistent", %{"name" => "Ghost"})
    end

    test "returns schema validation error for invalid update", %{workspace: workspace} do
      {:ok, {id, _data, _body}} =
        Brain.create(workspace, "people", %{"name" => "Irene"})

      assert {:error, _} = Brain.update(workspace, "people", id, %{"name" => 123})
    end
  end

  describe "delete/3" do
    test "deletes existing entity", %{workspace: workspace} do
      {:ok, {id, _data, _body}} = Brain.create(workspace, "people", %{"name" => "Jack"})

      assert :ok = Brain.delete(workspace, "people", id)
      assert {:error, :not_found} = Brain.read(workspace, "people", id)
    end

    test "returns not_found for nonexistent entity", %{workspace: workspace} do
      Brain.ensure_initialized(workspace)
      assert {:error, :not_found} = Brain.delete(workspace, "people", "nonexistent")
    end
  end

  describe "list/2" do
    test "returns empty list when no entities exist", %{workspace: workspace} do
      assert {:ok, []} = Brain.list(workspace, "people")
    end

    test "lists all entities of a type", %{workspace: workspace} do
      Brain.create(workspace, "people", %{"name" => "Alice"})
      Brain.create(workspace, "people", %{"name" => "Bob"})
      Brain.create(workspace, "people", %{"name" => "Charlie"})

      assert {:ok, entities} = Brain.list(workspace, "people")
      assert length(entities) == 3

      names = Enum.map(entities, fn {data, _body} -> data["name"] end) |> Enum.sort()
      assert names == ["Alice", "Bob", "Charlie"]
    end

    test "auto-initializes brain on first list", %{workspace: workspace} do
      refute File.exists?(Path.join(workspace, "brain"))

      {:ok, []} = Brain.list(workspace, "people")

      assert File.dir?(Path.join([workspace, "brain", "schemas"]))
    end

    test "does not include entities from other types", %{workspace: workspace} do
      Brain.create(workspace, "people", %{"name" => "Alice"})
      Brain.create(workspace, "companies", %{"name" => "Acme Corp"})

      {:ok, people} = Brain.list(workspace, "people")
      assert length(people) == 1

      {:ok, companies} = Brain.list(workspace, "companies")
      assert length(companies) == 1
    end
  end
end
