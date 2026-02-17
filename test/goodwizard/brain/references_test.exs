defmodule Goodwizard.Brain.ReferencesTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Brain
  alias Goodwizard.Brain.{References, Schema}

  setup do
    workspace =
      Path.join(
        System.tmp_dir!(),
        "brain_refs_test_" <> Integer.to_string(:rand.uniform(100_000))
      )

    on_exit(fn ->
      # Brief pause to let any async sweep tasks finish before cleanup
      Process.sleep(50)
      File.rm_rf!(workspace)
    end)

    Brain.ensure_initialized(workspace)
    %{workspace: workspace}
  end

  describe "ref_fields/1" do
    test "detects single ref field", %{workspace: workspace} do
      {:ok, schema} = Schema.load(workspace, "people")
      refs = References.ref_fields(schema)

      assert {"company", :single_ref, "companies"} in refs
    end

    test "detects ref list fields", %{workspace: workspace} do
      {:ok, schema} = Schema.load(workspace, "events")
      refs = References.ref_fields(schema)

      assert {"attendees", :ref_list, "people"} in refs
    end

    test "detects base ref list fields (notes, webpages)", %{workspace: workspace} do
      {:ok, schema} = Schema.load(workspace, "people")
      refs = References.ref_fields(schema)

      assert {"notes", :ref_list, "notes"} in refs
      assert {"webpages", :ref_list, "webpages"} in refs
    end

    test "detects polymorphic ref list (related_to on notes)", %{workspace: workspace} do
      {:ok, schema} = Schema.load(workspace, "notes")
      refs = References.ref_fields(schema)

      assert {"related_to", :poly_ref_list} in refs
    end

    test "does not include non-reference fields", %{workspace: workspace} do
      {:ok, schema} = Schema.load(workspace, "people")
      refs = References.ref_fields(schema)
      field_names = Enum.map(refs, &elem(&1, 0))

      refute "name" in field_names
      refute "id" in field_names
      refute "metadata" in field_names
      refute "created_at" in field_names
      refute "updated_at" in field_names
      refute "emails" in field_names
      refute "tags" in field_names
    end

    test "does not include url fields as refs", %{workspace: workspace} do
      {:ok, schema} = Schema.load(workspace, "webpages")
      refs = References.ref_fields(schema)
      field_names = Enum.map(refs, &elem(&1, 0))

      refute "url" in field_names
      refute "title" in field_names
      refute "description" in field_names
    end

    test "detects all ref shapes on events schema", %{workspace: workspace} do
      {:ok, schema} = Schema.load(workspace, "events")
      refs = References.ref_fields(schema)

      assert {"location", :single_ref, "places"} in refs
      assert {"attendees", :ref_list, "people"} in refs
      assert {"notes", :ref_list, "notes"} in refs
      assert {"webpages", :ref_list, "webpages"} in refs
    end

    test "detects tasks ref list on tasklists", %{workspace: workspace} do
      {:ok, schema} = Schema.load(workspace, "tasklists")
      refs = References.ref_fields(schema)

      assert {"tasks", :ref_list, "tasks"} in refs
    end

    test "detects contacts ref list on companies", %{workspace: workspace} do
      {:ok, schema} = Schema.load(workspace, "companies")
      refs = References.ref_fields(schema)

      assert {"contacts", :ref_list, "people"} in refs
    end

    test "detects assignee single ref on tasks", %{workspace: workspace} do
      {:ok, schema} = Schema.load(workspace, "tasks")
      refs = References.ref_fields(schema)

      assert {"assignee", :single_ref, "people"} in refs
    end

    test "returns sorted by field name", %{workspace: workspace} do
      {:ok, schema} = Schema.load(workspace, "events")
      refs = References.ref_fields(schema)
      field_names = Enum.map(refs, &elem(&1, 0))

      assert field_names == Enum.sort(field_names)
    end
  end

  describe "clean_data/3" do
    test "sets single ref to nil when target entity is deleted", %{workspace: workspace} do
      {:ok, {company_id, _, _}} = Brain.create(workspace, "companies", %{"name" => "Acme"})

      {:ok, {person_id, _, _}} =
        Brain.create(workspace, "people", %{
          "name" => "Alice",
          "company" => "companies/#{company_id}"
        })

      # Delete the company
      Brain.delete(workspace, "companies", company_id)

      {:ok, schema} = Schema.load(workspace, "people")
      {:ok, {data, _body}} = Brain.read(workspace, "people", person_id)

      cleaned = References.clean_data(workspace, schema, data)
      assert cleaned["company"] == nil
      assert cleaned["name"] == "Alice"
    end

    test "preserves single ref when target entity exists", %{workspace: workspace} do
      {:ok, {company_id, _, _}} = Brain.create(workspace, "companies", %{"name" => "Acme"})

      {:ok, {person_id, _, _}} =
        Brain.create(workspace, "people", %{
          "name" => "Alice",
          "company" => "companies/#{company_id}"
        })

      {:ok, schema} = Schema.load(workspace, "people")
      {:ok, {data, _body}} = Brain.read(workspace, "people", person_id)

      cleaned = References.clean_data(workspace, schema, data)
      assert cleaned["company"] == "companies/#{company_id}"
    end

    test "filters stale entries from ref list", %{workspace: workspace} do
      {:ok, {note1_id, _, _}} = Brain.create(workspace, "notes", %{"title" => "Note 1"})
      {:ok, {note2_id, _, _}} = Brain.create(workspace, "notes", %{"title" => "Note 2"})

      {:ok, {person_id, _, _}} =
        Brain.create(workspace, "people", %{
          "name" => "Bob",
          "notes" => ["notes/#{note1_id}", "notes/#{note2_id}"]
        })

      # Delete one note
      Brain.delete(workspace, "notes", note1_id)

      {:ok, schema} = Schema.load(workspace, "people")
      {:ok, {data, _body}} = Brain.read(workspace, "people", person_id)

      cleaned = References.clean_data(workspace, schema, data)
      assert cleaned["notes"] == ["notes/#{note2_id}"]
    end

    test "filters stale entries from polymorphic ref list", %{workspace: workspace} do
      {:ok, {person_id, _, _}} = Brain.create(workspace, "people", %{"name" => "Alice"})
      {:ok, {company_id, _, _}} = Brain.create(workspace, "companies", %{"name" => "Acme"})

      {:ok, {note_id, _, _}} =
        Brain.create(workspace, "notes", %{
          "title" => "Meeting",
          "related_to" => ["people/#{person_id}", "companies/#{company_id}"]
        })

      # Delete the company
      Brain.delete(workspace, "companies", company_id)

      {:ok, schema} = Schema.load(workspace, "notes")
      {:ok, {data, _body}} = Brain.read(workspace, "notes", note_id)

      cleaned = References.clean_data(workspace, schema, data)
      assert cleaned["related_to"] == ["people/#{person_id}"]
    end

    test "returns data unchanged when all refs are valid", %{workspace: workspace} do
      {:ok, {company_id, _, _}} = Brain.create(workspace, "companies", %{"name" => "Acme"})

      {:ok, {person_id, _, _}} =
        Brain.create(workspace, "people", %{
          "name" => "Alice",
          "company" => "companies/#{company_id}"
        })

      {:ok, schema} = Schema.load(workspace, "people")
      {:ok, {data, _body}} = Brain.read(workspace, "people", person_id)

      cleaned = References.clean_data(workspace, schema, data)
      assert cleaned == data
    end

    test "handles nil single ref field gracefully", %{workspace: workspace} do
      {:ok, {person_id, _, _}} = Brain.create(workspace, "people", %{"name" => "Alice"})

      {:ok, schema} = Schema.load(workspace, "people")
      {:ok, {data, _body}} = Brain.read(workspace, "people", person_id)

      cleaned = References.clean_data(workspace, schema, data)
      assert cleaned == data
    end

    test "handles missing ref list field gracefully", %{workspace: workspace} do
      {:ok, {person_id, _, _}} = Brain.create(workspace, "people", %{"name" => "Alice"})

      {:ok, schema} = Schema.load(workspace, "people")
      {:ok, {data, _body}} = Brain.read(workspace, "people", person_id)

      cleaned = References.clean_data(workspace, schema, data)
      assert cleaned == data
    end

    test "does not modify file on disk", %{workspace: workspace} do
      {:ok, {company_id, _, _}} = Brain.create(workspace, "companies", %{"name" => "Acme"})

      {:ok, {person_id, _, _}} =
        Brain.create(workspace, "people", %{
          "name" => "Alice",
          "company" => "companies/#{company_id}"
        })

      {:ok, path} = Goodwizard.Brain.Paths.entity_path(workspace, "people", person_id)
      original_content = File.read!(path)

      # Delete the company file directly (not via Brain.delete, to avoid async sweep)
      {:ok, company_path} = Goodwizard.Brain.Paths.entity_path(workspace, "companies", company_id)
      File.rm!(company_path)

      {:ok, schema} = Schema.load(workspace, "people")
      {:ok, {data, _body}} = read_raw(workspace, "people", person_id)
      _cleaned = References.clean_data(workspace, schema, data)

      # File should be unchanged
      assert File.read!(path) == original_content
    end
  end

  describe "validate/3" do
    test "returns stale single ref tuples", %{workspace: workspace} do
      {:ok, {company_id, _, _}} = Brain.create(workspace, "companies", %{"name" => "Acme"})

      {:ok, {person_id, _, _}} =
        Brain.create(workspace, "people", %{
          "name" => "Alice",
          "company" => "companies/#{company_id}"
        })

      Brain.delete(workspace, "companies", company_id)

      # Read raw data from disk (bypassing clean_data in Brain.read)
      {:ok, schema} = Schema.load(workspace, "people")
      {:ok, {data, _body}} = read_raw(workspace, "people", person_id)

      stale = References.validate(workspace, schema, data)
      assert {"company", "companies/#{company_id}"} in stale
    end

    test "returns stale ref list tuples", %{workspace: workspace} do
      {:ok, {note1_id, _, _}} = Brain.create(workspace, "notes", %{"title" => "Note 1"})
      {:ok, {note2_id, _, _}} = Brain.create(workspace, "notes", %{"title" => "Note 2"})

      {:ok, {person_id, _, _}} =
        Brain.create(workspace, "people", %{
          "name" => "Bob",
          "notes" => ["notes/#{note1_id}", "notes/#{note2_id}"]
        })

      Brain.delete(workspace, "notes", note1_id)

      {:ok, schema} = Schema.load(workspace, "people")
      {:ok, {data, _body}} = read_raw(workspace, "people", person_id)

      stale = References.validate(workspace, schema, data)
      assert {"notes", "notes/#{note1_id}"} in stale
      refute {"notes", "notes/#{note2_id}"} in stale
    end

    test "returns stale polymorphic ref tuples", %{workspace: workspace} do
      {:ok, {person_id, _, _}} = Brain.create(workspace, "people", %{"name" => "Alice"})
      {:ok, {company_id, _, _}} = Brain.create(workspace, "companies", %{"name" => "Acme"})

      {:ok, {note_id, _, _}} =
        Brain.create(workspace, "notes", %{
          "title" => "Meeting",
          "related_to" => ["people/#{person_id}", "companies/#{company_id}"]
        })

      Brain.delete(workspace, "companies", company_id)

      {:ok, schema} = Schema.load(workspace, "notes")
      {:ok, {data, _body}} = read_raw(workspace, "notes", note_id)

      stale = References.validate(workspace, schema, data)
      assert {"related_to", "companies/#{company_id}"} in stale
      refute {"related_to", "people/#{person_id}"} in stale
    end

    test "returns empty list when all refs are valid", %{workspace: workspace} do
      {:ok, {company_id, _, _}} = Brain.create(workspace, "companies", %{"name" => "Acme"})

      {:ok, {person_id, _, _}} =
        Brain.create(workspace, "people", %{
          "name" => "Alice",
          "company" => "companies/#{company_id}"
        })

      {:ok, schema} = Schema.load(workspace, "people")
      {:ok, {data, _body}} = Brain.read(workspace, "people", person_id)

      assert References.validate(workspace, schema, data) == []
    end

    test "returns empty list when entity has no refs", %{workspace: workspace} do
      {:ok, {person_id, _, _}} = Brain.create(workspace, "people", %{"name" => "Alice"})

      {:ok, schema} = Schema.load(workspace, "people")
      {:ok, {data, _body}} = Brain.read(workspace, "people", person_id)

      assert References.validate(workspace, schema, data) == []
    end
  end

  # Reads raw entity data from disk, bypassing Brain.read's clean_data
  defp read_raw(workspace, entity_type, id) do
    {:ok, path} = Goodwizard.Brain.Paths.entity_path(workspace, entity_type, id)
    {:ok, content} = File.read(path)
    Goodwizard.Brain.Entity.parse(content)
  end

  describe "sweep_stale/3" do
    test "removes single ref to deleted entity from disk", %{workspace: workspace} do
      {:ok, {company_id, _, _}} = Brain.create(workspace, "companies", %{"name" => "Acme"})

      {:ok, {person_id, _, _}} =
        Brain.create(workspace, "people", %{
          "name" => "Alice",
          "company" => "companies/#{company_id}"
        })

      # Delete the company (without sweep integration — call sweep directly)
      Brain.delete(workspace, "companies", company_id)
      References.sweep_stale(workspace, "companies", company_id)

      # Re-read from disk — the ref field should be absent (deleted, not nil)
      {:ok, {data, _body}} = Brain.read(workspace, "people", person_id)
      refute Map.has_key?(data, "company")
    end

    test "removes stale entries from ref list on disk", %{workspace: workspace} do
      {:ok, {person1_id, _, _}} = Brain.create(workspace, "people", %{"name" => "Alice"})
      {:ok, {person2_id, _, _}} = Brain.create(workspace, "people", %{"name" => "Bob"})

      {:ok, {company_id, _, _}} =
        Brain.create(workspace, "companies", %{
          "name" => "Acme",
          "contacts" => ["people/#{person1_id}", "people/#{person2_id}"]
        })

      Brain.delete(workspace, "people", person1_id)
      References.sweep_stale(workspace, "people", person1_id)

      {:ok, {data, _body}} = Brain.read(workspace, "companies", company_id)
      assert data["contacts"] == ["people/#{person2_id}"]
    end

    test "removes stale entries from polymorphic ref list on disk", %{workspace: workspace} do
      {:ok, {person_id, _, _}} = Brain.create(workspace, "people", %{"name" => "Alice"})
      {:ok, {company_id, _, _}} = Brain.create(workspace, "companies", %{"name" => "Acme"})

      {:ok, {note_id, _, _}} =
        Brain.create(workspace, "notes", %{
          "title" => "Meeting",
          "related_to" => ["people/#{person_id}", "companies/#{company_id}"]
        })

      Brain.delete(workspace, "people", person_id)
      References.sweep_stale(workspace, "people", person_id)

      {:ok, {data, _body}} = Brain.read(workspace, "notes", note_id)
      assert data["related_to"] == ["companies/#{company_id}"]
    end

    test "only scans relevant entity types", %{workspace: workspace} do
      # Create a task and a tasklist referencing it
      {:ok, {task_id, _, _}} = Brain.create(workspace, "tasks", %{"title" => "Do thing"})

      {:ok, {tasklist_id, _, _}} =
        Brain.create(workspace, "tasklists", %{
          "title" => "Sprint",
          "tasks" => ["tasks/#{task_id}"]
        })

      # Create an unrelated company
      {:ok, {company_id, _, _}} = Brain.create(workspace, "companies", %{"name" => "Acme"})

      Brain.delete(workspace, "tasks", task_id)
      References.sweep_stale(workspace, "tasks", task_id)

      # Tasklist should be cleaned
      {:ok, {tl_data, _body}} = Brain.read(workspace, "tasklists", tasklist_id)
      assert tl_data["tasks"] == []

      # Company should be untouched
      {:ok, {co_data, _body}} = Brain.read(workspace, "companies", company_id)
      assert co_data["name"] == "Acme"
    end

    test "sweep does not crash on empty types", %{workspace: workspace} do
      # Just ensure sweep runs without error when no entities of a type exist
      assert References.sweep_stale(workspace, "people", "nonexistent-id") == :ok
    end

    test "sweep handles polymorphic types scanning after any delete", %{workspace: workspace} do
      # Notes with polymorphic related_to should always be scanned
      {:ok, {place_id, _, _}} = Brain.create(workspace, "places", %{"name" => "Office"})

      {:ok, {note_id, _, _}} =
        Brain.create(workspace, "notes", %{
          "title" => "Office note",
          "related_to" => ["places/#{place_id}"]
        })

      Brain.delete(workspace, "places", place_id)
      References.sweep_stale(workspace, "places", place_id)

      {:ok, {data, _body}} = Brain.read(workspace, "notes", note_id)
      assert data["related_to"] == []
    end
  end
end
