defmodule Goodwizard.Channels.CLI.ServerMessageTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Channels.CLI.Server
  alias Goodwizard.Messaging

  setup do
    workspace = Path.join(System.tmp_dir!(), "gw_msg_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(workspace)
    on_exit(fn -> File.rm_rf!(workspace) end)

    {:ok, pid} = Server.start_link(workspace: workspace, start_repl: false)
    state = Server.get_state(pid)

    {:ok, pid: pid, state: state, workspace: workspace}
  end

  describe "send_input/2" do
    test "saves user message to room before dispatching", %{pid: pid, state: state} do
      Server.send_input(pid, "Hello")

      {:ok, messages} = Messaging.list_messages(state.room_id)

      user_messages = Enum.filter(messages, fn msg -> msg.role == :user end)
      assert user_messages != []

      assert Enum.any?(user_messages, fn msg ->
               msg.sender_id == "user" &&
                 match?([%{type: "text", text: text}] when is_binary(text), msg.content) &&
                 String.downcase(List.first(msg.content).text) == "hello"
             end)
    end

    test "saves assistant response to room after agent reply", %{pid: pid, state: state} do
      # Without API key, agent returns an error string as {:ok, error_text}
      # which still gets saved as the assistant message
      {:ok, _response} = Server.send_input(pid, "test query")

      {:ok, messages} = Messaging.list_messages(state.room_id)

      assistant_messages = Enum.filter(messages, fn msg -> msg.role == :assistant end)
      assert assistant_messages != []

      last_assistant = List.last(assistant_messages)
      assert last_assistant.sender_id == "assistant"
      assert [%{type: "text", text: text}] = last_assistant.content
      assert is_binary(text)
    end

    test "returns {:ok, response} with agent reply text", %{pid: pid} do
      {:ok, response} = Server.send_input(pid, "ping")
      assert is_binary(response)
    end
  end
end
