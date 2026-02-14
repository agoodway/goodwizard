defmodule Goodwizard.Actions.Messaging.SendTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Messaging.Send
  alias Goodwizard.Messaging

  describe "send message" do
    test "saves message to room and returns success with delivery info" do
      # Create a room first
      {:ok, room} =
        Messaging.get_or_create_room_by_external_binding(
          :cli,
          "test_send",
          "send_test_#{System.unique_integer([:positive])}",
          %{type: :direct, name: "Send Test"}
        )

      assert {:ok, result} =
               Send.run(%{room_id: room.id, content: "Hello from agent"}, %{})

      assert result.room_id == room.id
      assert result.persisted == true
      assert result.delivered == true
      assert is_binary(result.message_id)
      assert is_list(result.delivery_results)

      # Verify the message was persisted
      {:ok, messages} = Messaging.list_messages(room.id)
      agent_messages = Enum.filter(messages, fn msg -> msg.role == :assistant end)
      assert agent_messages != []

      last = List.last(agent_messages)
      assert last.sender_id == "assistant"
      assert [%{type: "text", text: "Hello from agent"}] = last.content
    end

    test "saves multiple messages to same room" do
      {:ok, room} =
        Messaging.get_or_create_room_by_external_binding(
          :cli,
          "test_send",
          "multi_test_#{System.unique_integer([:positive])}",
          %{type: :direct, name: "Multi Test"}
        )

      assert {:ok, _} = Send.run(%{room_id: room.id, content: "Message 1"}, %{})
      assert {:ok, _} = Send.run(%{room_id: room.id, content: "Message 2"}, %{})

      {:ok, messages} = Messaging.list_messages(room.id)
      agent_messages = Enum.filter(messages, fn msg -> msg.role == :assistant end)
      assert length(agent_messages) >= 2
    end

    test "returns delivery_results as empty list when no outbound bindings exist" do
      {:ok, room} =
        Messaging.get_or_create_room_by_external_binding(
          :cli,
          "test_send",
          "no_binding_test_#{System.unique_integer([:positive])}",
          %{type: :direct, name: "No Binding Test"}
        )

      assert {:ok, result} = Send.run(%{room_id: room.id, content: "test"}, %{})
      # No outbound bindings = no failures = delivered is true
      assert result.delivered == true
      assert result.delivery_results == []
    end
  end
end
