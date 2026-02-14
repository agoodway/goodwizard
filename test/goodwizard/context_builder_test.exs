defmodule Goodwizard.ContextBuilderTest do
  use ExUnit.Case, async: true

  alias Goodwizard.ContextBuilder

  describe "build_messages/1" do
    test "builds [system, user] without history" do
      messages =
        ContextBuilder.build_messages(
          system: "You are helpful.",
          history: [],
          user: "Hello"
        )

      assert [system, user] = messages
      assert system == %{role: :system, content: "You are helpful."}
      assert user == %{role: :user, content: "Hello"}
    end

    test "builds [system, ...history, user] with history" do
      history = [
        %{role: :user, content: "Previous question"},
        %{role: :assistant, content: "Previous answer"}
      ]

      messages =
        ContextBuilder.build_messages(
          system: "System prompt",
          history: history,
          user: "New question"
        )

      assert length(messages) == 4
      assert hd(messages).role == :system
      assert List.last(messages).role == :user
      assert List.last(messages).content == "New question"
      assert Enum.at(messages, 1).content == "Previous question"
      assert Enum.at(messages, 2).content == "Previous answer"
    end

    test "defaults history to empty list" do
      messages =
        ContextBuilder.build_messages(
          system: "System",
          user: "Hello"
        )

      assert length(messages) == 2
    end
  end

  describe "add_tool_result/4" do
    test "appends tool result message" do
      messages = [%{role: :system, content: "System"}]

      result =
        ContextBuilder.add_tool_result(messages, "call_123", "read_file", "file contents here")

      assert length(result) == 2
      tool_msg = List.last(result)
      assert tool_msg.role == :tool
      assert tool_msg.tool_call_id == "call_123"
      assert tool_msg.name == "read_file"
      assert tool_msg.content == "file contents here"
    end
  end

  describe "add_assistant_message/3" do
    test "appends plain assistant message" do
      messages = [%{role: :system, content: "System"}]

      result = ContextBuilder.add_assistant_message(messages, "I'll read that file for you.")

      assert length(result) == 2
      assistant_msg = List.last(result)
      assert assistant_msg.role == :assistant
      assert assistant_msg.content == "I'll read that file for you."
      refute Map.has_key?(assistant_msg, :tool_calls)
    end

    test "appends assistant message with tool calls" do
      messages = [%{role: :system, content: "System"}]
      tool_call = %{id: "call_1", name: "read_file", arguments: %{"path" => "/tmp/test.txt"}}

      result =
        ContextBuilder.add_assistant_message(messages, "Reading file...",
          tool_calls: [tool_call]
        )

      assistant_msg = List.last(result)
      assert assistant_msg.role == :assistant
      assert assistant_msg.content == "Reading file..."
      assert assistant_msg.tool_calls == [tool_call]
    end
  end
end
