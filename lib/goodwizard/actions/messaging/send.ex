defmodule Goodwizard.Actions.Messaging.Send do
  @moduledoc """
  Send a message to a room.

  Persists the message via Goodwizard.Messaging and attempts external
  delivery to any channels bound to the room.
  """

  use Jido.Action,
    name: "send_message",
    description: "Send a message to a room by room_id. The message is persisted and delivered to any bound external channels (e.g., Telegram).",
    schema: [
      room_id: [type: :string, required: true, doc: "The room to send the message to"],
      content: [type: :string, required: true, doc: "The message content to send"]
    ]

  require Logger

  alias Goodwizard.Messaging

  @channel_modules %{
    telegram: JidoMessaging.Channels.Telegram
  }

  @impl true
  def run(params, _context) do
    room_id = params.room_id
    content = params.content

    # Save message for persistence
    message_attrs = %{
      room_id: room_id,
      sender_id: "assistant",
      role: :assistant,
      content: [%{type: "text", text: content}],
      status: :sent
    }

    case Messaging.save_message(message_attrs) do
      {:ok, message} ->
        # Attempt external delivery to bound channels
        deliver_to_bindings(room_id, content)
        {:ok, %{message_id: message.id, room_id: room_id, delivered: true}}

      {:error, reason} ->
        {:error, "Failed to save message: #{inspect(reason)}"}
    end
  end

  defp deliver_to_bindings(room_id, content) do
    case Messaging.list_room_bindings(room_id) do
      {:ok, bindings} ->
        bindings
        |> Enum.filter(&outbound_enabled?/1)
        |> Enum.each(fn binding ->
          deliver_to_binding(binding, room_id, content)
        end)

      {:error, reason} ->
        Logger.debug("No bindings found for room #{room_id}: #{inspect(reason)}")
    end
  end

  defp outbound_enabled?(%{direction: direction, enabled: enabled}) do
    enabled and direction in [:both, :outbound]
  end

  defp deliver_to_binding(binding, room_id, content) do
    case Map.get(@channel_modules, binding.channel) do
      nil ->
        Logger.debug("No channel module for #{binding.channel}, skipping delivery")

      channel_module ->
        channel_context = %{
          channel: channel_module,
          external_room_id: binding.external_room_id
        }

        case JidoMessaging.Deliver.send_to_room(
               Messaging,
               room_id,
               content,
               channel_context
             ) do
          {:ok, _message} ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "Failed to deliver to #{binding.channel}:#{binding.external_room_id}: #{inspect(reason)}"
            )
        end
    end
  end
end
