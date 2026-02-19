defmodule Goodwizard.Actions.Memory.Procedural.DecayUnused do
  @moduledoc """
  Decays confidence of unused procedural memories and deletes stale ones.

  Wraps `Goodwizard.Memory.Procedural.decay_unused/2` as a callable agent action.
  """

  use Jido.Action,
    name: "decay_unused_procedures",
    description:
      "Demote confidence of procedures not used recently and delete stale low-confidence ones",
    schema: [
      decay_days: [
        type: :integer,
        default: 60,
        doc: "Days without use before confidence is demoted"
      ],
      archive_days: [
        type: :integer,
        default: 120,
        doc: "Days without use at low confidence before deletion"
      ]
    ]

  alias Goodwizard.Actions.Memory.Helpers
  alias Goodwizard.Memory.Procedural

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    memory_dir = Helpers.memory_dir(context)
    decay_days = Map.get(params, :decay_days, 60)
    archive_days = Map.get(params, :archive_days, 120)

    case Procedural.decay_unused(memory_dir, decay_days: decay_days, archive_days: archive_days) do
      {:ok, result} ->
        {:ok,
         Map.put(
           result,
           :message,
           "Decay complete: #{result.demoted} demoted, #{result.deleted} deleted, #{result.unchanged} unchanged"
         )}

      {:error, reason} ->
        {:error, "Decay failed: #{inspect(reason)}"}
    end
  end
end
