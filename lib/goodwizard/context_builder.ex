defmodule Goodwizard.ContextBuilder do
  @moduledoc """
  Message list operations for Goodwizard conversations.

  System prompt assembly is handled by `Goodwizard.Character.Hydrator`.
  This module focuses on building and manipulating the message list
  in the format expected by `Jido.AI.Conversation`.
  """

  # Note: append via ++ is O(n) but acceptable here — message lists are small
  # (bounded by conversation length). Prepend+reverse would complicate the API
  # for negligible gain.

  @doc """
  Build a message list from system prompt, history, and user input.

  Returns `[system_message, ...history_messages, user_message]`.

  ## Options

    * `:system` - System prompt string (required)
    * `:history` - List of history messages (default: `[]`)
    * `:user` - User message string (required)
  """
  @spec build_messages(keyword()) :: [map()]
  def build_messages(opts) do
    system_prompt = Keyword.fetch!(opts, :system)
    history = Keyword.get(opts, :history, [])
    user_message = Keyword.fetch!(opts, :user)

    [%{role: :system, content: system_prompt}] ++
      history ++
      [%{role: :user, content: user_message}]
  end

  @doc """
  Append a tool result message to the message list.
  """
  @spec add_tool_result([map()], String.t(), String.t(), String.t()) :: [map()]
  def add_tool_result(messages, tool_call_id, tool_name, result) do
    messages ++
      [
        %{
          role: :tool,
          tool_call_id: tool_call_id,
          name: tool_name,
          content: result
        }
      ]
  end

  @doc """
  Append an assistant message to the message list.

  ## Options

    * `:tool_calls` - List of tool call maps to include
  """
  @spec add_assistant_message([map()], String.t(), keyword()) :: [map()]
  def add_assistant_message(messages, content, opts \\ []) do
    message = %{role: :assistant, content: content}

    message =
      case Keyword.get(opts, :tool_calls) do
        nil -> message
        tool_calls -> Map.put(message, :tool_calls, tool_calls)
      end

    messages ++ [message]
  end
end
