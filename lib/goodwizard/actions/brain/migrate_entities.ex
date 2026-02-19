defmodule Goodwizard.Actions.Brain.MigrateEntities do
  @moduledoc """
  Applies a stored schema migration to all entities of a given type.
  """

  use Jido.Action,
    name: "migrate_entities",
    description: "Migrate entities of a type from one schema version to the next",
    schema: [
      entity_type: [
        type: :string,
        required: true,
        doc: "The entity type to migrate (e.g. \"people\", \"companies\")"
      ],
      from_version: [
        type: :integer,
        required: true,
        doc: "Source schema version"
      ],
      to_version: [
        type: :integer,
        required: true,
        doc: "Target schema version"
      ],
      dry_run: [
        type: :boolean,
        default: false,
        doc: "When true, validates and reports diffs without writing files"
      ]
    ]

  alias Goodwizard.Actions.Brain.Helpers

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    workspace = Helpers.workspace(context)

    case Goodwizard.Brain.migrate(
           workspace,
           params.entity_type,
           params.from_version,
           params.to_version,
           Map.get(params, :dry_run, false)
         ) do
      {:ok, summary} ->
        {:ok, summary}

      {:error, reason} ->
        {:error, Helpers.format_error(reason)}
    end
  end
end
