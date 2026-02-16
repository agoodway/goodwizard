defmodule Goodwizard.Brain.Seeds do
  @moduledoc """
  Default schema definitions for the brain knowledge base.

  Ships 7 initial entity type schemas as Elixir maps and writes them
  to disk on first use via `seed/1`.
  """

  alias Goodwizard.Brain.{Id, Paths, Schema}

  @entity_types ~w(people places events notes tasks companies tasklists)

  @doc "Returns the list of default entity type names."
  @spec entity_types() :: [String.t()]
  def entity_types, do: @entity_types

  @doc """
  Seeds all default schemas to disk if they don't already exist.

  Only writes schemas that are not yet present — safe to call multiple times.
  Returns `{:ok, seeded_types}` with the list of newly written types.
  """
  @spec seed(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def seed(workspace) do
    results =
      Enum.reduce_while(@entity_types, {:ok, []}, fn type, {:ok, seeded} ->
        case seed_type(workspace, type) do
          :skip -> {:cont, {:ok, seeded}}
          :ok -> {:cont, {:ok, [type | seeded]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case results do
      {:ok, seeded} -> {:ok, Enum.reverse(seeded)}
      error -> error
    end
  end

  defp seed_type(workspace, type) do
    with {:ok, path} <- Paths.schema_path(workspace, type) do
      if File.exists?(path), do: :skip, else: Schema.save(workspace, type, schema_for(type))
    end
  end

  @id_pattern Id.id_pattern()
  @uuid_pattern "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"

  @doc "Returns the schema map for a given entity type."
  @spec schema_for(String.t()) :: map()
  def schema_for("people") do
    build_schema("Person", ["id", "name"], %{
      "email" => %{"type" => "string", "format" => "email"},
      "phone" => %{"type" => "string"},
      "company" => entity_ref("companies"),
      "role" => %{"type" => "string"}
    })
  end

  def schema_for("places") do
    build_schema("Place", ["id", "name"], %{
      "address" => %{"type" => "string"},
      "city" => %{"type" => "string"},
      "state" => %{"type" => "string"},
      "country" => %{"type" => "string"},
      "coordinates" => %{
        "type" => "object",
        "properties" => %{
          "lat" => %{"type" => "number"},
          "lng" => %{"type" => "number"}
        },
        "required" => ["lat", "lng"],
        "additionalProperties" => false
      }
    })
  end

  def schema_for("events") do
    build_schema("Event", ["id", "title", "date"], %{
      "title" => %{"type" => "string"},
      "date" => %{"type" => "string", "format" => "date-time"},
      "location" => entity_ref("places"),
      "attendees" => entity_ref_list("people"),
      "description" => %{"type" => "string"}
    })
  end

  def schema_for("notes") do
    build_schema("Note", ["id", "title"], %{
      "title" => %{"type" => "string"},
      "topic" => %{"type" => "string"},
      "related_to" => %{
        "type" => "array",
        "items" => %{"type" => "string", "pattern" => "^[a-z_]+/#{@uuid_pattern}$"},
        "description" => "Polymorphic entity references (any entity type)"
      }
    })
  end

  def schema_for("tasks") do
    build_schema("Task", ["id", "title"], %{
      "title" => %{"type" => "string"},
      "status" => %{
        "type" => "string",
        "enum" => ["pending", "in_progress", "done", "cancelled"]
      },
      "priority" => %{
        "type" => "string",
        "enum" => ["low", "medium", "high"]
      },
      "due_date" => %{"type" => "string", "format" => "date-time"},
      "assignee" => entity_ref("people")
    })
  end

  def schema_for("companies") do
    build_schema("Company", ["id", "name"], %{
      "domain" => %{"type" => "string"},
      "industry" => %{"type" => "string"},
      "size" => %{"type" => "string"},
      "location" => %{"type" => "string"},
      "contacts" => entity_ref_list("people")
    })
  end

  def schema_for("tasklists") do
    build_schema("Tasklist", ["id", "title"], %{
      "title" => %{"type" => "string"},
      "description" => %{"type" => "string"},
      "status" => %{
        "type" => "string",
        "enum" => ["active", "completed", "archived"]
      },
      "tasks" => entity_ref_list("tasks")
    })
  end

  defp build_schema(title, required, custom_properties) do
    %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "title" => title,
      "version" => 1,
      "type" => "object",
      "required" => required,
      "properties" => Map.merge(base_properties(), custom_properties),
      "additionalProperties" => false
    }
  end

  defp base_properties do
    %{
      "id" => %{"type" => "string", "pattern" => @id_pattern},
      "name" => %{"type" => "string"},
      "notes" => entity_ref_list("notes"),
      "tags" => %{"type" => "array", "items" => %{"type" => "string"}},
      "created_at" => %{"type" => "string", "format" => "date-time"},
      "updated_at" => %{"type" => "string", "format" => "date-time"}
    }
  end

  defp entity_ref(type) do
    %{
      "type" => "string",
      "pattern" => "^#{type}/#{@uuid_pattern}$",
      "description" => "Entity reference to #{type}"
    }
  end

  defp entity_ref_list(type) do
    %{
      "type" => "array",
      "items" => %{"type" => "string", "pattern" => "^#{type}/#{@uuid_pattern}$"},
      "description" => "Entity references to #{type}"
    }
  end
end
