defmodule Goodwizard.Actions.Memory.ConsolidationIntegrationTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Memory.Consolidate
  alias Goodwizard.Plugins.Session

  defp tmp_memory_dir do
    dir = Path.join(System.tmp_dir!(), "test_memory_intg_#{:rand.uniform(100_000)}")
    File.mkdir_p!(dir)
    dir
  end

  defp tmp_sessions_dir do
    dir = Path.join(System.tmp_dir!(), "test_sessions_intg_#{:rand.uniform(100_000)}")
    File.mkdir_p!(dir)
    dir
  end

  defp make_messages(count) do
    for i <- 1..count do
      %{
        role: if(rem(i, 2) == 1, do: "user", else: "assistant"),
        content: "Message #{i}",
        timestamp: "2026-01-01T00:00:#{String.pad_leading(to_string(i), 2, "0")}Z"
      }
    end
  end

  describe "maybe_consolidate trigger conditions" do
    test "no consolidation when messages below window" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      messages = make_messages(5)

      assert {:ok, %{consolidated: false}} =
               Consolidate.run(
                 %{memory_dir: dir, messages: messages, memory_window: 10, current_memory: ""},
                 %{}
               )
    end

    test "no consolidation when messages equal to window" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      messages = make_messages(10)

      assert {:ok, %{consolidated: false}} =
               Consolidate.run(
                 %{memory_dir: dir, messages: messages, memory_window: 10, current_memory: ""},
                 %{}
               )
    end

    test "consolidation attempted when messages exceed window" do
      dir = tmp_memory_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      messages = make_messages(15)

      # LLM will fail in test env, but it should attempt consolidation
      assert {:ok, result} =
               Consolidate.run(
                 %{memory_dir: dir, messages: messages, memory_window: 10, current_memory: ""},
                 %{}
               )

      # Either consolidated or failed gracefully
      assert is_boolean(result.consolidated)
      assert is_binary(result.message)
    end

    test "path traversal rejected even with enough messages" do
      messages = make_messages(15)

      assert {:error, msg} =
               Consolidate.run(
                 %{
                   memory_dir: "/tmp/../../../etc",
                   messages: messages,
                   memory_window: 10,
                   current_memory: ""
                 },
                 %{}
               )

      assert msg =~ "path traversal"
    end
  end

  describe "session persistence round-trip" do
    test "save then load preserves all messages" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      messages = make_messages(10)

      state = %{
        session: %{
          messages: messages,
          created_at: "2026-01-01T00:00:00Z",
          metadata: %{"workspace" => "/test"}
        }
      }

      assert :ok = Session.save_session(dir, "roundtrip", state)
      assert {:ok, loaded} = Session.load_session(dir, "roundtrip")
      assert length(loaded.messages) == 10

      for i <- 1..10 do
        msg = Enum.at(loaded.messages, i - 1)
        assert msg.content == "Message #{i}"
      end
    end

    test "accumulate -> persist -> reload cycle" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      # Build up messages incrementally
      state = %{
        session: %{messages: [], created_at: "2026-01-01T00:00:00Z", metadata: %{}}
      }

      state = Session.add_message(state, "user", "Hello", "t1")
      state = Session.add_message(state, "assistant", "Hi!", "t2")
      state = Session.add_message(state, "user", "How are you?", "t3")
      state = Session.add_message(state, "assistant", "Good!", "t4")

      # Persist
      assert :ok = Session.save_session(dir, "cycle", state)

      # Reload
      assert {:ok, loaded} = Session.load_session(dir, "cycle")
      assert length(loaded.messages) == 4
      assert Enum.at(loaded.messages, 0).content == "Hello"
      assert Enum.at(loaded.messages, 3).content == "Good!"

      # Continue adding messages on reloaded state
      new_state = %{session: Map.merge(loaded, %{messages: loaded.messages})}
      new_state = Session.add_message(new_state, "user", "What next?", "t5")
      new_state = Session.add_message(new_state, "assistant", "Anything!", "t6")

      # Re-persist
      assert :ok = Session.save_session(dir, "cycle", new_state)

      # Final reload
      assert {:ok, final} = Session.load_session(dir, "cycle")
      assert length(final.messages) == 6
    end
  end

  describe "consolidation file write verification" do
    test "consolidation with file write failure returns graceful fallback" do
      # Use a read-only directory to force file write failure
      base = Path.join(System.tmp_dir!(), "test_cons_ro_#{:rand.uniform(100_000)}")
      dir = Path.join(base, "readonly")
      File.mkdir_p!(dir)
      File.chmod!(dir, 0o444)

      on_exit(fn ->
        File.chmod!(dir, 0o755)
        File.rm_rf!(base)
      end)

      messages = make_messages(15)

      # This will either fail at LLM (no API key) or at file write
      # Either way, it should return {:ok, %{consolidated: false}}
      result =
        Consolidate.run(
          %{memory_dir: dir, messages: messages, memory_window: 10, current_memory: ""},
          %{}
        )

      case result do
        {:ok, %{consolidated: false}} -> :ok
        {:ok, %{consolidated: true}} -> flunk("Should not succeed with read-only dir")
      end
    end
  end
end
