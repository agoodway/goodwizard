defmodule Goodwizard.Brain do
  @moduledoc """
  Entry point for the brain knowledge base subsystem.

  Handles initialization including directory creation and schema seeding
  on first access.
  """

  alias Goodwizard.Brain.{Paths, Schema, Seeds}

  @doc """
  Ensures the brain directory structure exists and seeds default schemas
  if the schemas directory is empty.

  Safe to call multiple times — only seeds on first use.
  Returns `{:ok, seeded_types}` where `seeded_types` is the list of
  newly created schema types (empty list if already seeded).
  """
  @spec ensure_initialized(String.t()) :: {:ok, [String.t()]} | {:error, term()}
  def ensure_initialized(workspace) do
    brain_dir = Paths.brain_dir(workspace)
    schemas_dir = Paths.schemas_dir(workspace)

    with :ok <- File.mkdir_p(brain_dir),
         :ok <- File.mkdir_p(schemas_dir),
         {:ok, existing} <- Schema.list_types(workspace) do
      if existing == [] do
        Seeds.seed(workspace)
      else
        {:ok, []}
      end
    end
  end
end
