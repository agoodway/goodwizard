defmodule Goodwizard.Brain.SchemaMapperTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Brain.SchemaMapper

  @person_schema %{
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
      "age" => %{"type" => "integer"},
      "created_at" => %{"type" => "string", "format" => "date-time"},
      "updated_at" => %{"type" => "string", "format" => "date-time"}
    }
  }

  describe "for_create/1" do
    test "excludes system fields (id, created_at, updated_at)" do
      {:ok, schema} = SchemaMapper.for_create(@person_schema)
      field_names = Keyword.keys(schema)
      refute :id in field_names
      refute :created_at in field_names
      refute :updated_at in field_names
    end

    test "marks required non-system fields as required" do
      {:ok, schema} = SchemaMapper.for_create(@person_schema)
      assert Keyword.get(schema, :name)[:required] == true
    end

    test "leaves optional fields without required flag" do
      {:ok, schema} = SchemaMapper.for_create(@person_schema)
      refute Keyword.has_key?(Keyword.get(schema, :age), :required)
      refute Keyword.has_key?(Keyword.get(schema, :emails), :required)
    end

    test "appends body field at the end" do
      {:ok, schema} = SchemaMapper.for_create(@person_schema)
      {last_key, last_opts} = List.last(schema)
      assert last_key == :body
      assert last_opts[:type] == :string
      assert last_opts[:default] == ""
    end

    test "sorts fields alphabetically" do
      {:ok, schema} = SchemaMapper.for_create(@person_schema)
      field_names = Keyword.keys(schema) -- [:body]
      assert field_names == Enum.sort(field_names)
    end

    test "returns error for invalid property names" do
      bad_schema = %{
        "properties" => %{
          "Valid_Name" => %{"type" => "string"}
        }
      }

      assert {:error, msg} = SchemaMapper.for_create(bad_schema)
      assert msg =~ "Invalid property name"
    end

    test "returns error for property names with spaces" do
      bad_schema = %{
        "properties" => %{
          "has space" => %{"type" => "string"}
        }
      }

      assert {:error, _} = SchemaMapper.for_create(bad_schema)
    end

    test "handles empty properties" do
      {:ok, schema} = SchemaMapper.for_create(%{"properties" => %{}})

      assert schema == [
               {:body, [type: :string, default: "", doc: "Optional markdown body content"]}
             ]
    end
  end

  describe "for_update/1" do
    test "prepends required id field" do
      {:ok, schema} = SchemaMapper.for_update(@person_schema)
      {first_key, first_opts} = hd(schema)
      assert first_key == :id
      assert first_opts[:required] == true
    end

    test "excludes system fields from entity fields" do
      {:ok, schema} = SchemaMapper.for_update(@person_schema)
      field_names = Keyword.keys(schema)
      refute :created_at in field_names
      refute :updated_at in field_names
    end

    test "all entity fields are optional (no required flag)" do
      {:ok, schema} = SchemaMapper.for_update(@person_schema)

      schema
      |> Keyword.delete(:id)
      |> Keyword.delete(:body)
      |> Enum.each(fn {_name, opts} ->
        refute Keyword.has_key?(opts, :required)
      end)
    end

    test "appends body field at the end" do
      {:ok, schema} = SchemaMapper.for_update(@person_schema)
      {last_key, _} = List.last(schema)
      assert last_key == :body
    end

    test "returns error for invalid property names" do
      bad_schema = %{
        "properties" => %{
          "123bad" => %{"type" => "string"}
        }
      }

      assert {:error, _} = SchemaMapper.for_update(bad_schema)
    end
  end

  describe "map_property/1" do
    test "maps string type" do
      assert SchemaMapper.map_property(%{"type" => "string"}) == [type: :string]
    end

    test "maps number type to float" do
      assert SchemaMapper.map_property(%{"type" => "number"}) == [type: :float]
    end

    test "maps integer type" do
      assert SchemaMapper.map_property(%{"type" => "integer"}) == [type: :integer]
    end

    test "maps boolean type" do
      assert SchemaMapper.map_property(%{"type" => "boolean"}) == [type: :boolean]
    end

    test "maps object type to map" do
      assert SchemaMapper.map_property(%{"type" => "object"}) == [type: :map]
    end

    test "maps string array to {:list, :string}" do
      prop = %{"type" => "array", "items" => %{"type" => "string"}}
      assert SchemaMapper.map_property(prop) == [type: {:list, :string}]
    end

    test "maps pattern array to {:list, :string}" do
      prop = %{"type" => "array", "items" => %{"pattern" => "^people/"}}
      opts = SchemaMapper.map_property(prop)
      assert opts[:type] == {:list, :string}
    end

    test "maps array of objects to {:list, :map}" do
      prop = %{"type" => "array", "items" => %{"type" => "object", "properties" => %{"value" => %{"type" => "string"}}}}
      assert SchemaMapper.map_property(prop) == [type: {:list, :map}]
    end

    test "maps array of objects with description includes doc" do
      prop = %{
        "type" => "array",
        "description" => "Email addresses",
        "items" => %{"type" => "object", "properties" => %{"value" => %{"type" => "string"}}}
      }

      opts = SchemaMapper.map_property(prop)
      assert opts[:type] == {:list, :map}
      assert opts[:doc] == "Email addresses"
    end

    test "maps array of objects without description has nil doc" do
      prop = %{
        "type" => "array",
        "items" => %{"type" => "object", "properties" => %{"value" => %{"type" => "string"}}}
      }

      opts = SchemaMapper.map_property(prop)
      assert opts[:type] == {:list, :map}
      refute Keyword.has_key?(opts, :doc)
    end

    test "maps generic array to {:list, :any}" do
      prop = %{"type" => "array"}
      assert SchemaMapper.map_property(prop) == [type: {:list, :any}]
    end

    test "defaults unknown type to string" do
      assert SchemaMapper.map_property(%{}) == [type: :string]
    end

    test "adds doc for enum strings" do
      prop = %{"type" => "string", "enum" => ["active", "inactive"]}
      opts = SchemaMapper.map_property(prop)
      assert opts[:doc] == "One of: active, inactive"
    end

    test "adds doc for email format" do
      prop = %{"type" => "string", "format" => "email"}
      opts = SchemaMapper.map_property(prop)
      assert opts[:doc] == "Email address"
    end

    test "adds doc for date-time format" do
      prop = %{"type" => "string", "format" => "date-time"}
      opts = SchemaMapper.map_property(prop)
      assert opts[:doc] == "ISO 8601 datetime"
    end

    test "adds doc for reference pattern" do
      prop = %{"type" => "string", "pattern" => "^companies/"}
      opts = SchemaMapper.map_property(prop)
      assert opts[:doc] =~ "Reference to a company"
    end

    test "adds doc from description" do
      prop = %{"type" => "string", "description" => "Custom desc"}
      opts = SchemaMapper.map_property(prop)
      assert opts[:doc] == "Custom desc"
    end
  end

  describe "singularize/1" do
    test "handles irregular plurals" do
      assert SchemaMapper.singularize("people") == "person"
      assert SchemaMapper.singularize("companies") == "company"
      assert SchemaMapper.singularize("categories") == "category"
      assert SchemaMapper.singularize("entries") == "entry"
      assert SchemaMapper.singularize("addresses") == "address"
    end

    test "handles -ies suffix" do
      assert SchemaMapper.singularize("stories") == "story"
      assert SchemaMapper.singularize("activities") == "activity"
    end

    test "handles -ses suffix" do
      assert SchemaMapper.singularize("classes") == "class"
    end

    test "handles regular -s suffix" do
      assert SchemaMapper.singularize("users") == "user"
      assert SchemaMapper.singularize("projects") == "project"
    end

    test "returns unchanged for non-plural words" do
      assert SchemaMapper.singularize("data") == "data"
    end
  end
end
