defmodule Goodwizard.Actions.Memory.Consolidate do
  @moduledoc """
  LLM-driven memory consolidation.

  Takes old session messages (beyond the memory window), formats them,
  calls the LLM for a consolidation summary, then updates HISTORY.md
  and MEMORY.md accordingly, and trims the session to the most recent
  N messages.
  """

  use Jido.Action,
    name: "consolidate",
    description: "Consolidate old conversation messages into long-term memory and history",
    schema: [
      memory_dir: [type: :string, required: true, doc: "Path to the memory directory"],
      messages: [type: {:list, :map}, required: true, doc: "All session messages"],
      memory_window: [type: :integer, default: 50, doc: "Number of recent messages to keep"],
      current_memory: [type: :string, default: "", doc: "Current MEMORY.md content"]
    ]

  require Logger

  @consolidation_prompt """
  You are a memory consolidation assistant. You will receive a conversation transcript
  and the current long-term memory content. Your job is to:

  1. Summarize the key information from the conversation into a history entry
  2. Extract any important facts, preferences, or knowledge that should be remembered long-term

  Current long-term memory:
  ---
  %{current_memory}
  ---

  Conversation to consolidate:
  ---
  %{formatted_messages}
  ---

  Respond with ONLY a JSON object (no markdown fencing) with these fields:
  - "history_entry": A concise summary of this conversation segment (1-3 sentences)
  - "memory_update": Updated long-term memory content (preserve existing important info, add new insights)
  """

  @impl true
  def run(params, _context) do
    messages = params.messages
    memory_window = Map.get(params, :memory_window, 50)
    current_memory = Map.get(params, :current_memory, "")
    memory_dir = params.memory_dir

    total = length(messages)

    if total <= memory_window do
      {:ok, %{consolidated: false, message: "No consolidation needed", messages: messages}}
    else
      old_messages = Enum.take(messages, total - memory_window)
      recent_messages = Enum.take(messages, -memory_window)

      formatted = format_messages(old_messages)

      prompt =
        @consolidation_prompt
        |> String.replace("%{current_memory}", current_memory)
        |> String.replace("%{formatted_messages}", formatted)

      case call_llm(prompt) do
        {:ok, %{"history_entry" => history_entry, "memory_update" => memory_update}} ->
          with :ok <- append_history(memory_dir, history_entry),
               :ok <- write_memory(memory_dir, memory_update) do
            {:ok,
             %{
               consolidated: true,
               message: "Consolidated #{length(old_messages)} messages",
               messages: recent_messages,
               memory_content: memory_update
             }}
          end

        {:error, reason} ->
          Logger.warning("Consolidation LLM call failed: #{inspect(reason)}")
          {:ok, %{consolidated: false, message: "Consolidation failed: #{inspect(reason)}", messages: messages}}
      end
    end
  end

  defp format_messages(messages) do
    messages
    |> Enum.map(fn msg ->
      timestamp = Map.get(msg, :timestamp, "unknown")
      role = Map.get(msg, :role, "unknown")
      content = Map.get(msg, :content, "")
      "[#{timestamp}] #{role}: #{content}"
    end)
    |> Enum.join("\n")
  end

  defp call_llm(prompt) do
    case Jido.Exec.run(Jido.AI.Actions.LLM.Chat, %{
           prompt: prompt,
           model: "anthropic:claude-haiku-4-5",
           max_tokens: 2048
         }) do
      {:ok, %{text: text}} ->
        parse_json_response(text)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_json_response(content) when is_binary(content) do
    # Strip markdown fencing if present
    cleaned =
      content
      |> String.trim()
      |> String.replace(~r/^```json\n?/, "")
      |> String.replace(~r/\n?```$/, "")
      |> String.trim()

    case Jason.decode(cleaned) do
      {:ok, %{"history_entry" => _, "memory_update" => _} = result} ->
        {:ok, result}

      {:ok, _other} ->
        {:error, "LLM response missing required fields (history_entry, memory_update)"}

      {:error, reason} ->
        {:error, "Failed to parse LLM response as JSON: #{inspect(reason)}"}
    end
  end

  defp parse_json_response(content) when is_list(content) do
    # Handle structured content blocks from Anthropic API
    text =
      content
      |> Enum.filter(fn block -> Map.get(block, :type) == "text" || Map.get(block, "type") == "text" end)
      |> Enum.map(fn block -> Map.get(block, :text) || Map.get(block, "text") || "" end)
      |> Enum.join("")

    parse_json_response(text)
  end

  defp append_history(memory_dir, entry) do
    path = Path.join(memory_dir, "HISTORY.md")
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    line = "[#{timestamp}] #{entry}\n"

    with :ok <- File.mkdir_p(memory_dir) do
      File.write(path, line, [:append])
    end
  end

  defp write_memory(memory_dir, content) do
    path = Path.join(memory_dir, "MEMORY.md")

    with :ok <- File.mkdir_p(memory_dir) do
      File.write(path, content)
    end
  end
end
