defmodule Goodwizard.Actions.Memory.Episodic.SearchEpisodes do
  @moduledoc """
  Searches past episodic memory entries by text query and/or filters.
  """

  use Jido.Action,
    name: "search_episodes",
    description:
      "Search past experiences by text query, tags, type, or outcome. Returns matching episodes sorted by relevance.",
    schema: [
      query: [
        type: :string,
        required: false,
        doc: "Text to search for in episode summaries, bodies, and tags"
      ],
      tags: [
        type: {:list, :string},
        required: false,
        doc: "Filter by tags (episodes must have all listed tags)"
      ],
      type: [
        type: :string,
        required: false,
        doc:
          "Filter by episode type: task_completion, problem_solved, error_encountered, decision_made, or interaction"
      ],
      outcome: [
        type: :string,
        required: false,
        doc: "Filter by outcome: success, failure, partial, or abandoned"
      ],
      limit: [
        type: :integer,
        required: false,
        doc: "Maximum number of results to return (default 10)"
      ]
    ]

  alias Goodwizard.Actions.Memory.Helpers
  alias Goodwizard.Memory.Episodic

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    memory_dir = Helpers.memory_dir(context)
    query = Map.get(params, :query, "")
    opts = build_opts(params)

    case Episodic.search(memory_dir, query, opts) do
      {:ok, episodes} ->
        {:ok, %{episodes: episodes, count: length(episodes)}}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp build_opts(params) do
    []
    |> maybe_add(:tags, Map.get(params, :tags))
    |> maybe_add(:type, Map.get(params, :type))
    |> maybe_add(:outcome, Map.get(params, :outcome))
    |> maybe_add(:limit, Map.get(params, :limit))
  end

  defp maybe_add(opts, _key, nil), do: opts
  defp maybe_add(opts, key, value), do: Keyword.put(opts, key, value)

  defp format_error(reason), do: "Failed to search episodes: #{inspect(reason)}"
end
