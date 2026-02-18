defmodule Goodwizard.Actions.Heartbeat.UpdateChecks do
  @moduledoc """
  Manages heartbeat awareness checks in HEARTBEAT.md.

  Supports three operations:
  - `add` — Append a new check to HEARTBEAT.md (creates the file if missing)
  - `remove` — Remove a check by matching text
  - `list` — Return all current checks
  """

  use Jido.Action,
    name: "update_heartbeat_checks",
    description:
      "Manage heartbeat awareness checks. " <>
        "Use operation \"add\" with text to add a new periodic check, " <>
        "\"remove\" with text to remove an existing check, " <>
        "or \"list\" to see all current checks.",
    schema: [
      operation: [
        type: :string,
        required: true,
        doc: "Operation to perform: \"add\", \"remove\", or \"list\""
      ],
      text: [
        type: :string,
        required: false,
        doc: "Check text (required for add/remove, ignored for list)"
      ]
    ]

  alias Goodwizard.Actions.Brain.Helpers
  alias Goodwizard.Heartbeat.Parser

  @valid_operations ~w(add remove list)
  @max_text_bytes 500

  @impl true
  def run(params, context) do
    operation = params.operation
    text = Map.get(params, :text)
    workspace = Helpers.workspace(context)
    heartbeat_path = Path.join(workspace, "HEARTBEAT.md")

    with :ok <- validate_operation(operation),
         :ok <- validate_text(operation, text) do
      text = if is_binary(text), do: String.trim(text), else: text
      execute(operation, text, heartbeat_path)
    end
  end

  defp validate_operation(op) when op in @valid_operations, do: :ok

  defp validate_operation(op),
    do: {:error, "Invalid operation #{inspect(op)} — must be \"add\", \"remove\", or \"list\""}

  defp validate_text("list", _text), do: :ok

  defp validate_text(_op, text) when is_binary(text) and text != "" do
    cond do
      byte_size(text) > @max_text_bytes ->
        {:error, "text exceeds maximum length of #{@max_text_bytes} bytes"}

      String.contains?(text, ["\n", "\r", "\0"]) ->
        {:error, "text must not contain newlines or null bytes"}

      true ->
        :ok
    end
  end

  defp validate_text(op, _text), do: {:error, "text is required for #{op} operation"}

  defp execute("add", text, path) do
    with {:ok, content} <- read_file(path) do
      case Parser.parse(content) do
        {:structured, checks} ->
          add_structured_check(path, content, checks, text)

        {:plain, _} ->
          append_check_line(path, content, text, 1)
      end
    end
  end

  defp execute("remove", text, path) do
    with {:ok, content} <- read_file(path) do
      case Parser.parse(content) do
        {:structured, checks} ->
          remove_structured_check(path, content, checks, text)

        {:plain, _} ->
          {:error, "Check not found: #{text}"}
      end
    end
  end

  defp execute("list", _text, path) do
    with {:ok, content} <- read_file(path) do
      case Parser.parse(content) do
        {:structured, checks} ->
          {:ok, %{checks: Enum.map(checks, & &1.text), total_checks: length(checks)}}

        {:plain, _} ->
          {:ok, %{checks: [], total_checks: 0}}
      end
    end
  end

  defp matches_check?(check_text, user_text) do
    String.downcase(String.trim(check_text)) == String.downcase(String.trim(user_text))
  end

  defp add_structured_check(path, content, checks, text) do
    if Enum.any?(checks, &matches_check?(&1.text, text)) do
      {:error, "Check already exists: #{text}"}
    else
      append_check_line(path, content, text, length(checks) + 1)
    end
  end

  defp append_check_line(path, content, text, total_checks) do
    new_line = "- [ ] #{text}"
    updated = if content == "", do: new_line, else: content <> "\n" <> new_line

    with :ok <- write_file(path, updated <> "\n") do
      {:ok, %{added: text, total_checks: total_checks}}
    end
  end

  defp remove_structured_check(path, content, checks, text) do
    if Enum.any?(checks, &matches_check?(&1.text, text)) do
      lines =
        content
        |> String.split("\n")
        |> Enum.reject(&matching_check_line?(&1, text))

      with :ok <- write_file(path, Enum.join(lines, "\n") <> "\n") do
        {:ok, %{removed: text, total_checks: length(checks) - 1}}
      end
    else
      {:error, "Check not found: #{text}"}
    end
  end

  defp matching_check_line?(line, text) do
    case Parser.match_check_line(line) do
      {:ok, check_text} -> matches_check?(check_text, text)
      :nomatch -> false
    end
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, String.trim(content)}
      {:error, :enoent} -> {:ok, ""}
      {:error, reason} -> {:error, "Failed to read #{path}: #{inspect(reason)}"}
    end
  end

  defp write_file(path, content) do
    tmp_path = path <> ".tmp"

    with :ok <- File.write(tmp_path, content),
         :ok <- File.rename(tmp_path, path) do
      :ok
    else
      {:error, reason} ->
        File.rm(tmp_path)
        {:error, "Failed to write #{path}: #{inspect(reason)}"}
    end
  end
end
