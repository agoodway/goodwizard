defmodule Mix.Tasks.Goodwizard.MigrateContactsTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Brain.{Entity, Paths}
  alias Mix.Tasks.Goodwizard.MigrateContacts

  import ExUnit.CaptureIO

  setup do
    workspace = Path.join(System.tmp_dir!(), "migrate_contacts_test_#{:rand.uniform(100_000)}")
    on_exit(fn -> File.rm_rf!(workspace) end)
    %{workspace: workspace}
  end

  defp setup_entity(workspace, type, data, body \\ "") do
    {:ok, type_dir} = Paths.entity_type_dir(workspace, type)
    File.mkdir_p!(type_dir)

    id = "test-#{:rand.uniform(100_000)}"
    path = Path.join(type_dir, "#{id}.md")
    content = Entity.serialize(Map.put(data, "id", id), body)
    File.write!(path, content)

    {id, path}
  end

  describe "migrate_type/3 for people" do
    test "migrates scalar email to emails array", %{workspace: workspace} do
      {id, path} = setup_entity(workspace, "people", %{
        "name" => "Alice",
        "email" => "alice@example.com"
      })

      result = MigrateContacts.migrate_type(workspace, "people", %{
        "email" => "emails",
        "phone" => "phones"
      })

      assert result.migrated == 1
      assert result.skipped == 0

      {:ok, content} = File.read(path)
      {:ok, {data, _body}} = Entity.parse(content)

      assert data["emails"] == [%{"type" => "primary", "value" => "alice@example.com"}]
      refute Map.has_key?(data, "email")
    end

    test "migrates scalar phone to phones array", %{workspace: workspace} do
      {_id, path} = setup_entity(workspace, "people", %{
        "name" => "Bob",
        "phone" => "555-0100"
      })

      result = MigrateContacts.migrate_type(workspace, "people", %{
        "email" => "emails",
        "phone" => "phones"
      })

      assert result.migrated == 1

      {:ok, content} = File.read(path)
      {:ok, {data, _body}} = Entity.parse(content)

      assert data["phones"] == [%{"type" => "primary", "value" => "555-0100"}]
      refute Map.has_key?(data, "phone")
    end

    test "migrates both email and phone in one entity", %{workspace: workspace} do
      {_id, path} = setup_entity(workspace, "people", %{
        "name" => "Charlie",
        "email" => "charlie@example.com",
        "phone" => "555-0200"
      })

      result = MigrateContacts.migrate_type(workspace, "people", %{
        "email" => "emails",
        "phone" => "phones"
      })

      assert result.migrated == 1

      {:ok, content} = File.read(path)
      {:ok, {data, _body}} = Entity.parse(content)

      assert data["emails"] == [%{"type" => "primary", "value" => "charlie@example.com"}]
      assert data["phones"] == [%{"type" => "primary", "value" => "555-0200"}]
    end

    test "skips entities without old fields", %{workspace: workspace} do
      setup_entity(workspace, "people", %{
        "name" => "Dave",
        "emails" => [%{"type" => "work", "value" => "dave@work.com"}]
      })

      result = MigrateContacts.migrate_type(workspace, "people", %{
        "email" => "emails",
        "phone" => "phones"
      })

      assert result.migrated == 0
      assert result.skipped == 1
    end

    test "skips entities with no contact fields at all", %{workspace: workspace} do
      setup_entity(workspace, "people", %{"name" => "Eve"})

      result = MigrateContacts.migrate_type(workspace, "people", %{
        "email" => "emails",
        "phone" => "phones"
      })

      assert result.migrated == 0
      assert result.skipped == 1
    end
  end

  describe "migrate_type/3 for companies" do
    test "migrates scalar location to addresses array", %{workspace: workspace} do
      {_id, path} = setup_entity(workspace, "companies", %{
        "name" => "Acme Corp",
        "location" => "Springfield, IL"
      })

      result = MigrateContacts.migrate_type(workspace, "companies", %{
        "location" => "addresses"
      })

      assert result.migrated == 1

      {:ok, content} = File.read(path)
      {:ok, {data, _body}} = Entity.parse(content)

      assert data["addresses"] == [%{"type" => "primary", "city" => "Springfield, IL"}]
      refute Map.has_key?(data, "location")
    end

    test "skips companies without location", %{workspace: workspace} do
      setup_entity(workspace, "companies", %{"name" => "Beta Inc"})

      result = MigrateContacts.migrate_type(workspace, "companies", %{
        "location" => "addresses"
      })

      assert result.migrated == 0
      assert result.skipped == 1
    end
  end

  describe "migrate_type/3 mixed batch" do
    test "reports correct counts for mixed entities", %{workspace: workspace} do
      # Entity 1: needs migration
      setup_entity(workspace, "people", %{
        "name" => "Migrate Me",
        "email" => "migrate@example.com"
      })

      # Entity 2: already migrated
      setup_entity(workspace, "people", %{
        "name" => "Already Done",
        "emails" => [%{"value" => "done@example.com"}]
      })

      # Entity 3: needs migration
      setup_entity(workspace, "people", %{
        "name" => "Also Migrate",
        "phone" => "555-9999"
      })

      result = MigrateContacts.migrate_type(workspace, "people", %{
        "email" => "emails",
        "phone" => "phones"
      })

      assert result.migrated == 2
      assert result.skipped == 1
      assert result.errors == []
    end
  end

  describe "migrate_type/3 when directory doesn't exist" do
    test "returns zero counts", %{workspace: workspace} do
      result = MigrateContacts.migrate_type(workspace, "people", %{
        "email" => "emails"
      })

      assert result == %{migrated: 0, skipped: 0, errors: []}
    end
  end

  describe "migrate_data/2" do
    test "converts email to emails array" do
      data = %{"name" => "Test", "email" => "test@example.com"}

      assert {:migrated, new_data} =
               MigrateContacts.migrate_data(data, %{"email" => "emails"})

      assert new_data["emails"] == [%{"type" => "primary", "value" => "test@example.com"}]
      refute Map.has_key?(new_data, "email")
      assert new_data["name"] == "Test"
    end

    test "converts location to addresses array" do
      data = %{"name" => "Test", "location" => "New York"}

      assert {:migrated, new_data} =
               MigrateContacts.migrate_data(data, %{"location" => "addresses"})

      assert new_data["addresses"] == [%{"type" => "primary", "city" => "New York"}]
      refute Map.has_key?(new_data, "location")
    end

    test "returns :skip when no old fields present" do
      data = %{"name" => "Test"}
      assert :skip = MigrateContacts.migrate_data(data, %{"email" => "emails"})
    end

    test "returns :skip when old field is nil" do
      data = %{"name" => "Test", "email" => nil}
      assert :skip = MigrateContacts.migrate_data(data, %{"email" => "emails"})
    end
  end

  describe "run/1 end-to-end" do
    setup do
      workspace = Path.join(System.tmp_dir!(), "migrate_e2e_test_#{:rand.uniform(100_000)}")
      File.mkdir_p!(workspace)

      Application.ensure_all_started(:goodwizard)

      original_workspace = Goodwizard.Config.workspace()
      Goodwizard.Config.put(["agent", "workspace"], workspace)
      on_exit(fn ->
        Goodwizard.Config.put(["agent", "workspace"], original_workspace)
        File.rm_rf!(workspace)
      end)

      %{workspace: workspace}
    end

    test "migrates people and companies and upgrades schemas", %{workspace: workspace} do
      # Set up a person with scalar email
      {_id, person_path} = setup_entity(workspace, "people", %{
        "name" => "E2E Person",
        "email" => "e2e@example.com",
        "phone" => "555-0001"
      })

      # Set up a company with scalar location
      {_id, company_path} = setup_entity(workspace, "companies", %{
        "name" => "E2E Corp",
        "location" => "Austin, TX"
      })

      output = capture_io(fn ->
        MigrateContacts.run([])
      end)

      # Verify shell output
      assert output =~ "Migrating contact fields"
      assert output =~ "people: 1 migrated, 0 skipped"
      assert output =~ "companies: 1 migrated, 0 skipped"

      # Verify person was migrated
      {:ok, content} = File.read(person_path)
      {:ok, {data, _body}} = Entity.parse(content)
      assert data["emails"] == [%{"type" => "primary", "value" => "e2e@example.com"}]
      assert data["phones"] == [%{"type" => "primary", "value" => "555-0001"}]
      refute Map.has_key?(data, "email")
      refute Map.has_key?(data, "phone")

      # Verify company was migrated
      {:ok, content} = File.read(company_path)
      {:ok, {data, _body}} = Entity.parse(content)
      assert data["addresses"] == [%{"type" => "primary", "city" => "Austin, TX"}]
      refute Map.has_key?(data, "location")

      # Verify schemas were upgraded
      {:ok, people_schema_path} = Paths.schema_path(workspace, "people")
      assert File.exists?(people_schema_path)
      {:ok, schema_json} = File.read(people_schema_path)
      {:ok, schema} = Jason.decode(schema_json)
      assert schema["version"] == 2
      assert Map.has_key?(schema["properties"], "emails")

      {:ok, companies_schema_path} = Paths.schema_path(workspace, "companies")
      assert File.exists?(companies_schema_path)
      {:ok, schema_json} = File.read(companies_schema_path)
      {:ok, schema} = Jason.decode(schema_json)
      assert schema["version"] == 2
      assert Map.has_key?(schema["properties"], "emails")
    end
  end
end
