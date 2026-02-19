defmodule Goodwizard.Actions.Memory.Episodic.ReadEpisode do
  @moduledoc """
  Reads a specific episodic memory entry by ID.
  """

  use Jido.Action,
    name: "read_episode",
    description:
      "Read a specific past experience by its ID. Returns the full episode with metadata and body content.",
    schema: [
      id: [
        type: :string,
        required: true,
        doc: "The ID of the episode to read"
      ]
    ]

  alias Goodwizard.Actions.Memory.Helpers
  alias Goodwizard.Memory.Episodic

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    memory_dir = Helpers.memory_dir(context)

    case Episodic.read(memory_dir, params.id) do
      {:ok, {frontmatter, body}} ->
        {:ok, %{frontmatter: frontmatter, body: body}}

      {:error, :not_found} ->
        {:error, "Episode not found: #{params.id}"}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp format_error(:invalid_id), do: "Invalid episode ID format"
  defp format_error(reason), do: "Failed to read episode: #{inspect(reason)}"
end
