defmodule Goodwizard.Actions.Messaging.Send do
  @moduledoc """
  Send a message to a room.

  Persists the message via Goodwizard.Messaging and attempts external
  delivery to any channels bound to the room.
  """

  use Jido.Action,
    name: "send_message",
    description:
      "Send a message to a room by room_id. The message is persisted and delivered to any bound external channels (e.g., Telegram).",
    schema: [
      room_id: [type: :string, required: true, doc: "The room to send the message to"],
      content: [type: :string, required: true, doc: "The message content to send"]
    ]

  alias Goodwizard.Messaging
  alias Goodwizard.Messaging.Delivery

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
        delivery_results = Delivery.deliver_to_bindings(room_id, content)
        failures = Enum.filter(delivery_results, &match?({:error, _, _}, &1))

        {:ok,
         %{
           message_id: message.id,
           room_id: room_id,
           persisted: true,
           delivered: failures == [],
           delivery_results: delivery_results
         }}

      {:error, reason} ->
        {:error, "Failed to save message: #{inspect(reason)}"}
    end
  end
end
