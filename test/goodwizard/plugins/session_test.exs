defmodule Goodwizard.Plugins.SessionTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Plugins.Session

  defp state_with_session(messages \\ []) do
    %{
      session: %{
        messages: messages,
        created_at: "2026-01-01T00:00:00Z",
        metadata: %{foo: "bar"}
      }
    }
  end

  describe "mount/2" do
    test "initializes with created_at timestamp" do
      {:ok, plugin_state} = Session.mount(%{}, %{})
      assert is_binary(plugin_state.created_at)
      assert {:ok, _, _} = DateTime.from_iso8601(plugin_state.created_at)
    end

    test "loads existing session file when session_key matches" do
      workspace = Path.join(System.tmp_dir!(), "gw_mount_test_#{System.unique_integer([:positive])}")
      sessions_dir = Path.join(workspace, "sessions")
      File.mkdir_p!(sessions_dir)

      # Write a session file
      session_key = "telegram-12345"
      metadata_line = Jason.encode!(%{key: session_key, created_at: "2026-01-15T10:00:00Z", version: 1, metadata: %{source: "test"}})
      msg_line = Jason.encode!(%{role: "user", content: "Hello from file", timestamp: "2026-01-15T10:00:01Z"})
      File.write!(Path.join(sessions_dir, "telegram-12345.jsonl"), metadata_line <> "\n" <> msg_line <> "\n")

      agent = %{state: %{session_key: session_key, workspace: workspace}}
      {:ok, plugin_state} = Session.mount(agent, %{})

      assert plugin_state.created_at == "2026-01-15T10:00:00Z"
      assert plugin_state.metadata == %{"source" => "test"}
      assert length(plugin_state.messages) == 1
      assert hd(plugin_state.messages).content == "Hello from file"

      File.rm_rf!(workspace)
    end

    test "starts empty when no file matches session_key" do
      workspace = Path.join(System.tmp_dir!(), "gw_mount_empty_#{System.unique_integer([:positive])}")
      sessions_dir = Path.join(workspace, "sessions")
      File.mkdir_p!(sessions_dir)

      agent = %{state: %{session_key: "cli-direct-9999999999", workspace: workspace}}
      {:ok, plugin_state} = Session.mount(agent, %{})

      # Should get a fresh created_at (not from file) and empty messages
      assert is_binary(plugin_state.created_at)
      assert {:ok, _, _} = DateTime.from_iso8601(plugin_state.created_at)
      refute Map.has_key?(plugin_state, :messages)

      File.rm_rf!(workspace)
    end

    test "starts empty when agent has no session_key" do
      agent = %{state: %{workspace: "/tmp/whatever"}}
      {:ok, plugin_state} = Session.mount(agent, %{})

      assert is_binary(plugin_state.created_at)
      refute Map.has_key?(plugin_state, :messages)
    end
  end

  describe "add_message/4" do
    test "appends user message to empty session" do
      state = state_with_session()
      updated = Session.add_message(state, "user", "Hello", "2026-01-01T00:00:01Z")

      assert [%{role: "user", content: "Hello", timestamp: "2026-01-01T00:00:01Z"}] =
               updated.session.messages
    end

    test "appends assistant message" do
      state = state_with_session()
      updated = Session.add_message(state, "assistant", "Hi there", "2026-01-01T00:00:01Z")

      assert [%{role: "assistant", content: "Hi there"}] = updated.session.messages
    end

    test "raises FunctionClauseError for invalid role" do
      state = state_with_session()

      assert_raise FunctionClauseError, fn ->
        Session.add_message(state, "invalid_role", "Hello", "2026-01-01T00:00:01Z")
      end
    end

    test "preserves insertion order" do
      state =
        state_with_session()
        |> Session.add_message("user", "First", "2026-01-01T00:00:01Z")
        |> Session.add_message("assistant", "Second", "2026-01-01T00:00:02Z")
        |> Session.add_message("user", "Third", "2026-01-01T00:00:03Z")

      messages = state.session.messages
      assert length(messages) == 3
      assert Enum.at(messages, 0).content == "First"
      assert Enum.at(messages, 1).content == "Second"
      assert Enum.at(messages, 2).content == "Third"
    end
  end

  describe "get_history/2" do
    test "returns all messages" do
      state =
        state_with_session()
        |> Session.add_message("user", "One", "t1")
        |> Session.add_message("assistant", "Two", "t2")
        |> Session.add_message("user", "Three", "t3")
        |> Session.add_message("assistant", "Four", "t4")
        |> Session.add_message("user", "Five", "t5")

      history = Session.get_history(state)
      assert length(history) == 5
    end

    test "returns limited most recent messages" do
      state =
        state_with_session()
        |> Session.add_message("user", "One", "t1")
        |> Session.add_message("assistant", "Two", "t2")
        |> Session.add_message("user", "Three", "t3")
        |> Session.add_message("assistant", "Four", "t4")
        |> Session.add_message("user", "Five", "t5")

      history = Session.get_history(state, limit: 3)
      assert length(history) == 3
      assert Enum.at(history, 0).content == "Three"
      assert Enum.at(history, 1).content == "Four"
      assert Enum.at(history, 2).content == "Five"
    end

    test "returns empty list for fresh session" do
      state = state_with_session()
      assert Session.get_history(state) == []
    end

    test "returns all messages for zero limit" do
      state =
        state_with_session()
        |> Session.add_message("user", "One", "t1")
        |> Session.add_message("assistant", "Two", "t2")

      history = Session.get_history(state, limit: 0)
      assert length(history) == 2
    end

    test "returns all messages for negative limit" do
      state =
        state_with_session()
        |> Session.add_message("user", "One", "t1")
        |> Session.add_message("assistant", "Two", "t2")

      history = Session.get_history(state, limit: -1)
      assert length(history) == 2
    end
  end

  describe "clear/1" do
    test "resets messages to empty" do
      state =
        state_with_session()
        |> Session.add_message("user", "Hello", "t1")
        |> Session.add_message("assistant", "Hi", "t2")

      cleared = Session.clear(state)
      assert cleared.session.messages == []
    end

    test "preserves created_at" do
      state =
        state_with_session()
        |> Session.add_message("user", "Hello", "t1")

      cleared = Session.clear(state)
      assert cleared.session.created_at == "2026-01-01T00:00:00Z"
    end

    test "preserves metadata" do
      state =
        state_with_session()
        |> Session.add_message("user", "Hello", "t1")

      cleared = Session.clear(state)
      assert cleared.session.metadata == %{foo: "bar"}
    end
  end
end
