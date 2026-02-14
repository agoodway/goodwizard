defmodule Goodwizard.Plugins.SessionPersistenceTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Plugins.Session

  defp tmp_sessions_dir do
    dir = Path.join(System.tmp_dir!(), "test_sessions_#{:rand.uniform(100_000)}")
    File.mkdir_p!(dir)
    dir
  end

  defp state_with_messages(messages) do
    %{
      session: %{
        messages: messages,
        created_at: "2026-01-01T00:00:00Z",
        metadata: %{"source" => "test"}
      }
    }
  end

  describe "save_session/3" do
    test "creates JSONL file with metadata and messages" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      messages = [
        %{role: "user", content: "Hello", timestamp: "2026-01-01T00:00:01Z"},
        %{role: "assistant", content: "Hi there!", timestamp: "2026-01-01T00:00:02Z"}
      ]

      state = state_with_messages(messages)
      assert :ok = Session.save_session(dir, "test_session", state)

      path = Path.join(dir, "test_session.jsonl")
      assert File.exists?(path)

      lines = path |> File.read!() |> String.split("\n", trim: true)
      assert length(lines) == 3
    end

    test "first line is metadata JSON" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      state = state_with_messages([])
      Session.save_session(dir, "meta_test", state)

      lines =
        Path.join(dir, "meta_test.jsonl")
        |> File.read!()
        |> String.split("\n", trim: true)

      metadata = Jason.decode!(Enum.at(lines, 0))
      assert metadata["key"] == "meta_test"
      assert metadata["created_at"] == "2026-01-01T00:00:00Z"
      assert metadata["version"] == 1
      assert metadata["metadata"] == %{"source" => "test"}
    end

    test "subsequent lines are message JSONs" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      messages = [
        %{role: "user", content: "Hello", timestamp: "t1"},
        %{role: "assistant", content: "Hi!", timestamp: "t2"}
      ]

      state = state_with_messages(messages)
      Session.save_session(dir, "msg_test", state)

      lines =
        Path.join(dir, "msg_test.jsonl")
        |> File.read!()
        |> String.split("\n", trim: true)

      msg1 = Jason.decode!(Enum.at(lines, 1))
      assert msg1["role"] == "user"
      assert msg1["content"] == "Hello"
      assert msg1["timestamp"] == "t1"

      msg2 = Jason.decode!(Enum.at(lines, 2))
      assert msg2["role"] == "assistant"
      assert msg2["content"] == "Hi!"
      assert msg2["timestamp"] == "t2"
    end

    test "replaces colons with underscores in filename" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      state = state_with_messages([])
      Session.save_session(dir, "cli:direct", state)

      assert File.exists?(Path.join(dir, "cli_direct.jsonl"))
      refute File.exists?(Path.join(dir, "cli:direct.jsonl"))
    end

    test "creates sessions directory if missing" do
      base = Path.join(System.tmp_dir!(), "test_sessions_nested_#{:rand.uniform(100_000)}")
      dir = Path.join(base, "sessions")
      on_exit(fn -> File.rm_rf!(base) end)

      refute File.exists?(dir)

      state = state_with_messages([])
      assert :ok = Session.save_session(dir, "auto_create", state)
      assert File.exists?(Path.join(dir, "auto_create.jsonl"))
    end

    test "overwrites existing session file" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      state1 = state_with_messages([%{role: "user", content: "First", timestamp: "t1"}])
      Session.save_session(dir, "overwrite", state1)

      state2 = state_with_messages([%{role: "user", content: "Second", timestamp: "t2"}])
      Session.save_session(dir, "overwrite", state2)

      lines =
        Path.join(dir, "overwrite.jsonl")
        |> File.read!()
        |> String.split("\n", trim: true)

      # Should have 1 metadata + 1 message (not 2 messages from both saves)
      assert length(lines) == 2
      msg = Jason.decode!(Enum.at(lines, 1))
      assert msg["content"] == "Second"
    end
  end

  describe "load_session/2" do
    test "loads saved session with messages" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      messages = [
        %{role: "user", content: "Hello", timestamp: "2026-01-01T00:00:01Z"},
        %{role: "assistant", content: "Hi!", timestamp: "2026-01-01T00:00:02Z"}
      ]

      state = state_with_messages(messages)
      Session.save_session(dir, "roundtrip", state)

      assert {:ok, loaded} = Session.load_session(dir, "roundtrip")
      assert length(loaded.messages) == 2

      assert Enum.at(loaded.messages, 0) == %{
               role: "user",
               content: "Hello",
               timestamp: "2026-01-01T00:00:01Z"
             }

      assert Enum.at(loaded.messages, 1) == %{
               role: "assistant",
               content: "Hi!",
               timestamp: "2026-01-01T00:00:02Z"
             }
    end

    test "restores created_at and metadata" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      state = state_with_messages([])
      Session.save_session(dir, "meta_load", state)

      assert {:ok, loaded} = Session.load_session(dir, "meta_load")
      assert loaded.created_at == "2026-01-01T00:00:00Z"
      assert loaded.metadata == %{"source" => "test"}
    end

    test "returns error when file not found" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      assert {:error, :not_found} = Session.load_session(dir, "nonexistent")
    end

    test "handles colon-based session keys" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      state = state_with_messages([%{role: "user", content: "CLI msg", timestamp: "t1"}])
      Session.save_session(dir, "cli:direct", state)

      assert {:ok, loaded} = Session.load_session(dir, "cli:direct")
      assert length(loaded.messages) == 1
      assert Enum.at(loaded.messages, 0).content == "CLI msg"
    end
  end

  describe "save then load round-trip" do
    test "messages survive save/load cycle" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      messages =
        for i <- 1..10 do
          %{
            role: if(rem(i, 2) == 1, do: "user", else: "assistant"),
            content: "Message #{i}",
            timestamp: "2026-01-01T00:00:#{String.pad_leading(to_string(i), 2, "0")}Z"
          }
        end

      state = state_with_messages(messages)
      Session.save_session(dir, "survival", state)

      assert {:ok, loaded} = Session.load_session(dir, "survival")
      assert length(loaded.messages) == 10

      for i <- 1..10 do
        msg = Enum.at(loaded.messages, i - 1)
        assert msg.content == "Message #{i}"
        assert msg.role == if(rem(i, 2) == 1, do: "user", else: "assistant")
      end
    end
  end
end
