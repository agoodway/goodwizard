defmodule Goodwizard.Actions.Memory.Procedural.UseProcedure do
  @moduledoc """
  Records usage of a procedure with success/failure outcome.
  """

  use Jido.Action,
    name: "use_procedure",
    description:
      "Record that a procedure was used and whether it succeeded or failed, updating confidence over time",
    schema: [
      id: [
        type: :string,
        required: true,
        doc: "The ID of the procedure that was used"
      ],
      outcome: [
        type: {:in, ~w(success failure)},
        required: true,
        doc: "Outcome of using the procedure: success or failure"
      ]
    ]

  alias Goodwizard.Actions.Memory.Helpers
  alias Goodwizard.Memory.Procedural

  @impl true
  @spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def run(params, context) do
    memory_dir = Helpers.memory_dir(context)

    outcome =
      case params.outcome do
        "success" -> :success
        "failure" -> :failure
      end

    case Procedural.record_usage(memory_dir, params.id, outcome) do
      {:ok, procedure} ->
        {:ok,
         %{
           procedure: procedure,
           message: "Procedure usage recorded (#{params.outcome})"
         }}

      {:error, :not_found} ->
        {:error, "Procedure not found: #{params.id}"}

      {:error, reason} ->
        {:error, format_error(reason)}
    end
  end

  defp format_error(:invalid_id), do: "Invalid procedure ID format"
  defp format_error({:fs_error, reason}), do: "File system error: #{:file.format_error(reason)}"
  defp format_error(reason), do: "Failed to record procedure usage: #{inspect(reason)}"
end
