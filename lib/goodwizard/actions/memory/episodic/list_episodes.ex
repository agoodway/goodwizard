defmodule Goodwizard.Actions.Memory.Episodic.ListEpisodes do
  @moduledoc """
  Lists recent episodic memory entries with optional filters.
  """

  use Jido.Action,
    name: "list_episodes",
    description:
      "List recent past experiences, sorted by most recent first. Optionally filter by type or outcome.",
    schema: [
      limit: [
        type: :integer,
        required: false,
        doc: "Maximum number of episodes to return (default 20)"
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
      ]
    ]

  alias Goodwizard.Actions.Memory.Episodic.Helpers
  alias Goodwizard.Memory.Episodic

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    memory_dir = Helpers.memory_dir(context)
    opts = build_opts(params)

    case Episodic.list(memory_dir, opts) do
      {:ok, episodes} ->
        {:ok, %{episodes: episodes, count: length(episodes)}}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp build_opts(params) do
    []
    |> maybe_add(:limit, Map.get(params, :limit))
    |> maybe_add(:type, Map.get(params, :type))
    |> maybe_add(:outcome, Map.get(params, :outcome))
  end

  defp maybe_add(opts, _key, nil), do: opts
  defp maybe_add(opts, key, value), do: Keyword.put(opts, key, value)

  defp format_error({:fs_error, reason}), do: "File system error: #{:file.format_error(reason)}"
  defp format_error(reason), do: "Failed to list episodes: #{inspect(reason)}"
end
