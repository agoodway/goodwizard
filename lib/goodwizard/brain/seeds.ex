defmodule Goodwizard.Brain.Seeds do
  @moduledoc """
  Default schema definitions for the brain knowledge base.

  Ships 6 initial entity type schemas as Elixir maps and writes them
  to disk on first use via `seed/1`.
  """

  alias Goodwizard.Brain.Schema

  @entity_types ~w(people places events notes tasks companies)

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
        {:ok, path} = Goodwizard.Brain.Paths.schema_path(workspace, type)

        if File.exists?(path) do
          {:cont, {:ok, seeded}}
        else
          case Schema.save(workspace, type, schema_for(type)) do
            :ok -> {:cont, {:ok, [type | seeded]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end
      end)

    case results do
      {:ok, seeded} -> {:ok, Enum.reverse(seeded)}
      error -> error
    end
  end

  @doc "Returns the schema map for a given entity type."
  @spec schema_for(String.t()) :: map()
  def schema_for("people") do
    %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "title" => "Person",
      "version" => 1,
      "type" => "object",
      "required" => ["id", "name"],
      "properties" => %{
        "id" => %{"type" => "string", "pattern" => "^[a-z0-9]{6,}$"},
        "name" => %{"type" => "string"},
        "email" => %{"type" => "string", "format" => "email"},
        "phone" => %{"type" => "string"},
        "company" => %{
          "type" => "string",
          "pattern" => "^companies/[a-z0-9]{6,}$",
          "description" => "Entity reference to companies"
        },
        "role" => %{"type" => "string"},
        "notes" => %{
          "type" => "array",
          "items" => %{"type" => "string", "pattern" => "^notes/[a-z0-9]{6,}$"},
          "description" => "Entity references to notes"
        },
        "tags" => %{"type" => "array", "items" => %{"type" => "string"}},
        "created_at" => %{"type" => "string", "format" => "date-time"},
        "updated_at" => %{"type" => "string", "format" => "date-time"}
      },
      "additionalProperties" => false
    }
  end

  def schema_for("places") do
    %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "title" => "Place",
      "version" => 1,
      "type" => "object",
      "required" => ["id", "name"],
      "properties" => %{
        "id" => %{"type" => "string", "pattern" => "^[a-z0-9]{6,}$"},
        "name" => %{"type" => "string"},
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
        },
        "notes" => %{
          "type" => "array",
          "items" => %{"type" => "string", "pattern" => "^notes/[a-z0-9]{6,}$"},
          "description" => "Entity references to notes"
        },
        "tags" => %{"type" => "array", "items" => %{"type" => "string"}},
        "created_at" => %{"type" => "string", "format" => "date-time"},
        "updated_at" => %{"type" => "string", "format" => "date-time"}
      },
      "additionalProperties" => false
    }
  end

  def schema_for("events") do
    %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "title" => "Event",
      "version" => 1,
      "type" => "object",
      "required" => ["id", "title", "date"],
      "properties" => %{
        "id" => %{"type" => "string", "pattern" => "^[a-z0-9]{6,}$"},
        "title" => %{"type" => "string"},
        "date" => %{"type" => "string", "format" => "date-time"},
        "location" => %{
          "type" => "string",
          "pattern" => "^places/[a-z0-9]{6,}$",
          "description" => "Entity reference to places"
        },
        "attendees" => %{
          "type" => "array",
          "items" => %{"type" => "string", "pattern" => "^people/[a-z0-9]{6,}$"},
          "description" => "Entity references to people"
        },
        "description" => %{"type" => "string"},
        "notes" => %{
          "type" => "array",
          "items" => %{"type" => "string", "pattern" => "^notes/[a-z0-9]{6,}$"},
          "description" => "Entity references to notes"
        },
        "tags" => %{"type" => "array", "items" => %{"type" => "string"}},
        "created_at" => %{"type" => "string", "format" => "date-time"},
        "updated_at" => %{"type" => "string", "format" => "date-time"}
      },
      "additionalProperties" => false
    }
  end

  def schema_for("notes") do
    %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "title" => "Note",
      "version" => 1,
      "type" => "object",
      "required" => ["id", "title"],
      "properties" => %{
        "id" => %{"type" => "string", "pattern" => "^[a-z0-9]{6,}$"},
        "title" => %{"type" => "string"},
        "topic" => %{"type" => "string"},
        "related_to" => %{
          "type" => "array",
          "items" => %{"type" => "string", "pattern" => "^[a-z_]+/[a-z0-9]{6,}$"},
          "description" => "Polymorphic entity references (any entity type)"
        },
        "tags" => %{"type" => "array", "items" => %{"type" => "string"}},
        "created_at" => %{"type" => "string", "format" => "date-time"},
        "updated_at" => %{"type" => "string", "format" => "date-time"}
      },
      "additionalProperties" => false
    }
  end

  def schema_for("tasks") do
    %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "title" => "Task",
      "version" => 1,
      "type" => "object",
      "required" => ["id", "title"],
      "properties" => %{
        "id" => %{"type" => "string", "pattern" => "^[a-z0-9]{6,}$"},
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
        "assignee" => %{
          "type" => "string",
          "pattern" => "^people/[a-z0-9]{6,}$",
          "description" => "Entity reference to people"
        },
        "notes" => %{
          "type" => "array",
          "items" => %{"type" => "string", "pattern" => "^notes/[a-z0-9]{6,}$"},
          "description" => "Entity references to notes"
        },
        "tags" => %{"type" => "array", "items" => %{"type" => "string"}},
        "created_at" => %{"type" => "string", "format" => "date-time"},
        "updated_at" => %{"type" => "string", "format" => "date-time"}
      },
      "additionalProperties" => false
    }
  end

  def schema_for("companies") do
    %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "title" => "Company",
      "version" => 1,
      "type" => "object",
      "required" => ["id", "name"],
      "properties" => %{
        "id" => %{"type" => "string", "pattern" => "^[a-z0-9]{6,}$"},
        "name" => %{"type" => "string"},
        "domain" => %{"type" => "string"},
        "industry" => %{"type" => "string"},
        "size" => %{"type" => "string"},
        "location" => %{"type" => "string"},
        "contacts" => %{
          "type" => "array",
          "items" => %{"type" => "string", "pattern" => "^people/[a-z0-9]{6,}$"},
          "description" => "Entity references to people"
        },
        "notes" => %{
          "type" => "array",
          "items" => %{"type" => "string", "pattern" => "^notes/[a-z0-9]{6,}$"},
          "description" => "Entity references to notes"
        },
        "tags" => %{"type" => "array", "items" => %{"type" => "string"}},
        "created_at" => %{"type" => "string", "format" => "date-time"},
        "updated_at" => %{"type" => "string", "format" => "date-time"}
      },
      "additionalProperties" => false
    }
  end
end
