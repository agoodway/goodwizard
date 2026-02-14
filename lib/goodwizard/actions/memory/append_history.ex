defmodule Goodwizard.Actions.Memory.AppendHistory do
  @moduledoc """
  Appends a timestamped entry to HISTORY.md.
  """

  use Jido.Action,
    name: "append_history",
    description: "Append a timestamped entry to conversation history (HISTORY.md)",
    schema: [
      memory_dir: [type: :string, required: true, doc: "Path to the memory directory"],
      entry: [type: :string, required: true, doc: "Entry text to append"]
    ]

  @impl true
  def run(params, _context) do
    path = Path.join(params.memory_dir, "HISTORY.md")
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    line = "[#{timestamp}] #{params.entry}\n"

    case File.mkdir_p(params.memory_dir) do
      :ok ->
        case File.write(path, line, [:append]) do
          :ok ->
            {:ok, %{message: "Appended entry to HISTORY.md"}}

          {:error, reason} ->
            {:error, "Failed to append to HISTORY.md: #{:file.format_error(reason)}"}
        end

      {:error, reason} ->
        {:error, "Failed to create memory directory: #{:file.format_error(reason)}"}
    end
  end
end
