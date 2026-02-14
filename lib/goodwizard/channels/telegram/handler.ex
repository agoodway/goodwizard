defmodule Goodwizard.Channels.Telegram.Handler do
  @moduledoc """
  Telegram channel handler using jido_messaging's Telegram.Handler macro.

  Uses Telegex-based long-polling via the Handler macro. The only custom code
  is the `handle_message/2` callback which routes messages to per-chat
  AgentServer instances.

  ## Configuration

  In `~/.goodwizard/config.toml`:

      [channels.telegram]
      enabled = true
      allow_from = [123456789]  # Telegram user IDs, empty = allow all

  Environment:

      TELEGRAM_BOT_TOKEN=your-bot-token

  """

  use JidoMessaging.Channels.Telegram.Handler,
    messaging: Goodwizard.Messaging,
    on_message: &Goodwizard.Channels.Telegram.Handler.handle_message/2

  require Logger

  alias Goodwizard.Agent, as: GoodwizardAgent
  alias Goodwizard.Messaging

  @ask_timeout 120_000
  @max_message_length 4096
  @assistant_sender_id "assistant"

  @doc """
  Callback invoked by the Handler macro for each incoming Telegram message.

  Checks the allow-list, gets or creates an AgentServer for the chat,
  dispatches the message, and returns the response.
  """
  def handle_message(message, context) do
    from_id = context.participant.external_ids[:telegram]

    if allowed?(from_id) do
      process_message(message, context)
    else
      :noreply
    end
  end

  @doc """
  Splits text into chunks that fit within Telegram's message size limit.

  Splits at newline boundaries when possible. Falls back to hard split
  at the limit when no newline is available.
  """
  @spec split_message(String.t()) :: [String.t()]
  def split_message(text) do
    if String.length(text) <= @max_message_length do
      [text]
    else
      split_message_acc(text, [])
      |> Enum.reverse()
    end
  end

  # -- Private -----------------------------------------------------------------

  defp process_message(message, context) do
    text = extract_text(message.content)
    chat_id = context.external_room_id
    room_id = context.room.id

    if text == "" do
      :noreply
    else
      case get_or_create_agent(chat_id) do
        {:ok, agent_pid} ->
          case GoodwizardAgent.ask_sync(agent_pid, text, timeout: @ask_timeout) do
            {:ok, answer} ->
              save_message(room_id, @assistant_sender_id, :assistant, answer)

              case split_message(answer) do
                [single] ->
                  {:reply, single}

                [first | rest] ->
                  # Return first chunk as reply; deliver remaining chunks directly
                  for chunk <- rest do
                    Telegex.send_message(chat_id, chunk)
                  end

                  {:reply, first}
              end

            {:error, reason} ->
              Logger.error("Agent error for chat #{chat_id}: #{inspect(reason)}")
              {:reply, "Sorry, I encountered an error. Please try again."}
          end

        {:error, reason} ->
          Logger.error("Failed to create agent for chat #{chat_id}: #{inspect(reason)}")
          {:reply, "Sorry, I'm unable to start a session right now."}
      end
    end
  end

  defp get_or_create_agent(chat_id) do
    workspace = Goodwizard.Config.workspace()

    case Goodwizard.Jido.start_agent(GoodwizardAgent,
           id: "telegram:#{chat_id}",
           initial_state: %{
             workspace: workspace,
             channel: "telegram",
             chat_id: "#{chat_id}",
             character_overrides: %{
               "tone" => "friendly",
               "style" => "brief and mobile-friendly"
             }
           }
         ) do
      {:ok, agent_pid} ->
        {:ok, agent_pid}

      {:error, {:already_started, agent_pid}} ->
        {:ok, agent_pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp allowed?(from_id) do
    allow_from = Goodwizard.Config.get(["channels", "telegram", "allow_from"]) || []

    case allow_from do
      [] -> true
      list -> from_id in list || "#{from_id}" in Enum.map(list, &to_string/1)
    end
  end

  defp extract_text([%{text: text} | _]) when is_binary(text), do: text
  defp extract_text([%JidoMessaging.Content.Text{text: text} | _]) when is_binary(text), do: text
  defp extract_text(_), do: ""

  defp save_message(room_id, sender_id, role, text) do
    case Messaging.save_message(%{
           room_id: room_id,
           sender_id: sender_id,
           role: role,
           content: [%{type: "text", text: text}]
         }) do
      {:ok, message} ->
        {:ok, message}

      {:error, reason} ->
        Logger.warning("Failed to save #{role} message: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp split_message_acc("", acc), do: acc

  defp split_message_acc(text, acc) do
    if String.length(text) <= @max_message_length do
      [text | acc]
    else
      chunk = String.slice(text, 0, @max_message_length)

      case last_newline_index(chunk) do
        nil ->
          # No newline found — force split at the limit
          rest = String.slice(text, @max_message_length, String.length(text))
          split_message_acc(rest, [chunk | acc])

        idx ->
          before = String.slice(text, 0, idx)
          rest = String.slice(text, idx + 1, String.length(text))
          split_message_acc(rest, [before | acc])
      end
    end
  end

  defp last_newline_index(string) do
    string
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reverse()
    |> Enum.find_value(fn
      {"\n", idx} -> idx
      _ -> nil
    end)
  end
end
