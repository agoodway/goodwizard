defmodule Goodwizard.Brain.Seeds do
  @moduledoc """
  Default schema definitions for the brain knowledge base.

  Ships initial entity type schemas as Elixir maps and writes them
  to disk on first use via `seed/1`.

  ## Schema versioning

  Each schema includes an advisory `"version"` integer (default 1).
  The version field is not read at runtime — it serves as metadata
  for operators inspecting schema files on disk.

  ## Security: SSRF considerations for webpages URLs

  The webpages entity stores user-provided URLs restricted to http/https schemes.
  If future features fetch webpage content (e.g., scraping, link previews), implementers
  must guard against SSRF by filtering private/internal IP ranges (RFC 1918, loopback,
  link-local), enforcing request timeouts, and considering a domain allowlist.
  """

  alias Goodwizard.Brain.{Id, Paths, Schema}

  @entity_types ~w(people places events notes tasks companies tasklists webpages)

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
  @uuid_pattern Id.id_pattern() |> String.trim_leading("^") |> String.trim_trailing("$")

  @doc "Returns the schema map for a given entity type."
  @spec schema_for(String.t()) :: map()
  def schema_for("people") do
    build_schema("Person", ["id", "name"], %{
      "emails" => contact_field("Email addresses"),
      "phones" => contact_field("Phone numbers"),
      "addresses" => address_field(),
      "socials" => contact_field("Social media profiles"),
      "company" => entity_ref("companies"),
      "role" => %{
        "type" => "string",
        "description" => "Job title or role at their company (e.g. CEO, Engineer, Sales Manager)"
      }
    }, 2)
  end

  def schema_for("places") do
    build_schema("Place", ["id", "name"], %{
      "address" => %{"type" => "string", "description" => "Street address line (e.g. 123 Main St)"},
      "city" => %{"type" => "string", "description" => "City name"},
      "state" => %{"type" => "string", "description" => "State, province, or region"},
      "country" => %{"type" => "string", "description" => "Country name or ISO code"},
      "coordinates" => %{
        "type" => "object",
        "description" => "Geographic coordinates",
        "properties" => %{
          "lat" => %{"type" => "number", "description" => "Latitude in decimal degrees"},
          "lng" => %{"type" => "number", "description" => "Longitude in decimal degrees"}
        },
        "required" => ["lat", "lng"],
        "additionalProperties" => false
      }
    })
  end

  def schema_for("events") do
    build_schema("Event", ["id", "title", "date"], %{
      "title" => %{"type" => "string", "description" => "Short name or subject of the event"},
      "date" => %{
        "type" => "string",
        "format" => "date-time",
        "description" => "When the event occurs (ISO 8601 datetime)"
      },
      "location" => entity_ref("places"),
      "attendees" => entity_ref_list("people"),
      "description" => %{
        "type" => "string",
        "description" => "Details, agenda, or notes about the event"
      }
    })
  end

  def schema_for("notes") do
    build_schema("Note", ["id", "title"], %{
      "title" => %{"type" => "string", "description" => "Short title or subject of the note"},
      "topic" => %{
        "type" => "string",
        "description" => "Category or topic area (e.g. meeting notes, ideas, research)"
      },
      "related_to" => %{
        "type" => "array",
        "items" => %{"type" => "string", "pattern" => "^[a-z_]+/#{@uuid_pattern}$"},
        "description" => "Polymorphic entity references (any entity type)"
      }
    })
  end

  def schema_for("tasks") do
    build_schema("Task", ["id", "title"], %{
      "title" => %{
        "type" => "string",
        "description" => "Short description of what needs to be done"
      },
      "status" => %{
        "type" => "string",
        "enum" => ["pending", "in_progress", "done", "cancelled"],
        "description" => "Current status of the task"
      },
      "priority" => %{
        "type" => "string",
        "enum" => ["low", "medium", "high"],
        "description" => "Urgency level of the task"
      },
      "due_date" => %{
        "type" => "string",
        "format" => "date-time",
        "description" => "Deadline for completing the task (ISO 8601 datetime)"
      },
      "assignee" => entity_ref("people")
    })
  end

  def schema_for("companies") do
    build_schema("Company", ["id", "name"], %{
      "domain" => %{"type" => "string", "description" => "Company website domain (e.g. example.com)"},
      "industry" => %{
        "type" => "string",
        "description" => "Business sector or industry (e.g. Technology, Healthcare, Finance)"
      },
      "size" => %{
        "type" => "string",
        "description" =>
          "Company size category (e.g. startup, small, medium, enterprise) or employee count"
      },
      "emails" => contact_field("Email addresses"),
      "phones" => contact_field("Phone numbers"),
      "addresses" => address_field(),
      "socials" => contact_field("Social media profiles"),
      "contacts" => entity_ref_list("people")
    }, 2)
  end

  def schema_for("tasklists") do
    build_schema("Tasklist", ["id", "title"], %{
      "title" => %{"type" => "string", "description" => "Name of the task list or project"},
      "description" => %{
        "type" => "string",
        "description" => "Purpose or scope of this task list"
      },
      "status" => %{
        "type" => "string",
        "enum" => ["active", "completed", "archived"],
        "description" => "Whether this list is active, completed, or archived"
      },
      "tasks" => entity_ref_list("tasks")
    })
  end

  def schema_for("webpages") do
    schema =
      build_schema("Webpage", ["id", "title", "url"], %{
        "title" => %{"type" => "string", "description" => "Page title or heading"},
        "url" => %{
          "type" => "string",
          "format" => "uri",
          "pattern" => "^https?://",
          "maxLength" => 2048,
          "description" => "Full URL of the webpage (must be http or https)"
        },
        "description" => %{
          "type" => "string",
          "maxLength" => 10_000,
          "description" => "Summary or description of the webpage content"
        }
      })

    Map.update!(schema, "properties", &Map.delete(&1, "webpages"))
  end

  defp build_schema(title, required, custom_properties, version \\ 1) do
    %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "title" => title,
      "version" => version,
      "type" => "object",
      "required" => required,
      "properties" => Map.merge(base_properties(), custom_properties),
      "additionalProperties" => false
    }
  end

  defp base_properties do
    %{
      "id" => %{
        "type" => "string",
        "pattern" => @id_pattern,
        "description" => "Unique identifier for this entity"
      },
      "name" => %{"type" => "string", "description" => "Primary name or display label"},
      "notes" => entity_ref_list("notes"),
      "webpages" => entity_ref_list("webpages"),
      "tags" => %{
        "type" => "array",
        "items" => %{"type" => "string"},
        "description" => "Freeform labels for categorization and search"
      },
      "created_at" => %{
        "type" => "string",
        "format" => "date-time",
        "description" => "When this entity was first created (ISO 8601)"
      },
      "updated_at" => %{
        "type" => "string",
        "format" => "date-time",
        "description" => "When this entity was last modified (ISO 8601)"
      }
    }
  end

  defp contact_field(description) do
    %{
      "type" => "array",
      "description" => description,
      "items" => %{
        "type" => "object",
        "properties" => %{
          "type" => %{
            "type" => "string",
            "description" => "Label for this entry (e.g. work, personal, home, mobile)"
          },
          "value" => %{
            "type" => "string",
            "description" => "The actual contact value (email address, phone number, etc.)"
          }
        },
        "required" => ["value"]
      }
    }
  end

  defp address_field do
    %{
      "type" => "array",
      "description" => "Postal addresses",
      "items" => %{
        "type" => "object",
        "properties" => %{
          "type" => %{
            "type" => "string",
            "description" => "Label for this address (e.g. home, work, headquarters)"
          },
          "street" => %{"type" => "string", "description" => "Street address line"},
          "city" => %{"type" => "string", "description" => "City name"},
          "state" => %{"type" => "string", "description" => "State, province, or region"},
          "zip" => %{"type" => "string", "description" => "ZIP or postal code"},
          "country" => %{"type" => "string", "description" => "Country name or ISO code"}
        },
        "required" => ["city"]
      }
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
