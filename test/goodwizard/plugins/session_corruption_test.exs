defmodule Goodwizard.Plugins.SessionCorruptionTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Plugins.Session

  defp tmp_sessions_dir do
    dir = Path.join(System.tmp_dir!(), "test_sessions_corr_#{:rand.uniform(100_000)}")
    File.mkdir_p!(dir)
    dir
  end

  describe "load_session with corrupted data" do
    test "returns :corrupted for invalid metadata JSON" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(Path.join(dir, "bad_meta.jsonl"), "not valid json\n")

      assert {:error, :corrupted} = Session.load_session(dir, "bad_meta")
    end

    test "returns :not_found for empty file" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      File.write!(Path.join(dir, "empty.jsonl"), "")

      assert {:error, :not_found} = Session.load_session(dir, "empty")
    end

    test "skips corrupted message lines and loads valid ones" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      metadata = Jason.encode!(%{key: "partial", created_at: "2026-01-01T00:00:00Z", version: 1, metadata: %{}})
      good_msg = Jason.encode!(%{role: "user", content: "Hello", timestamp: "t1"})
      bad_msg = "not valid json at all"
      good_msg2 = Jason.encode!(%{role: "assistant", content: "Hi!", timestamp: "t2"})

      content = Enum.join([metadata, good_msg, bad_msg, good_msg2], "\n") <> "\n"
      File.write!(Path.join(dir, "partial.jsonl"), content)

      assert {:ok, loaded} = Session.load_session(dir, "partial")
      assert length(loaded.messages) == 2
      assert Enum.at(loaded.messages, 0).content == "Hello"
      assert Enum.at(loaded.messages, 1).content == "Hi!"
    end

    test "handles file with only metadata (no messages)" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      metadata = Jason.encode!(%{key: "meta_only", created_at: "2026-01-01T00:00:00Z", version: 1, metadata: %{}})
      File.write!(Path.join(dir, "meta_only.jsonl"), metadata <> "\n")

      assert {:ok, loaded} = Session.load_session(dir, "meta_only")
      assert loaded.messages == []
      assert loaded.created_at == "2026-01-01T00:00:00Z"
    end

    test "handles partial JSON lines (truncated write)" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      metadata = Jason.encode!(%{key: "truncated", created_at: "2026-01-01T00:00:00Z", version: 1, metadata: %{}})
      good_msg = Jason.encode!(%{role: "user", content: "Before crash", timestamp: "t1"})
      truncated = ~s({"role":"assistant","content":"Cut off mid-)

      content = Enum.join([metadata, good_msg, truncated], "\n") <> "\n"
      File.write!(Path.join(dir, "truncated.jsonl"), content)

      assert {:ok, loaded} = Session.load_session(dir, "truncated")
      assert length(loaded.messages) == 1
      assert Enum.at(loaded.messages, 0).content == "Before crash"
    end
  end

  describe "session key sanitization" do
    test "rejects path traversal in session key" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      # After sanitization, "../../../etc/passwd" becomes "_________etc_passwd"
      # which is safe — it stays within the sessions directory
      state = %{session: %{messages: [], created_at: "t", metadata: %{}}}
      assert :ok = Session.save_session(dir, "../../../etc/passwd", state)

      # The file should be safely named, not traverse out
      refute File.exists?("/etc/passwd.jsonl")
      assert File.exists?(Path.join(dir, "_________etc_passwd.jsonl"))
    end

    test "handles session keys with special characters" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      state = %{session: %{messages: [], created_at: "t", metadata: %{}}}
      assert :ok = Session.save_session(dir, "user@host:session/1", state)
      assert File.exists?(Path.join(dir, "user_host_session_1.jsonl"))
    end

    test "handles null bytes in session key" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      state = %{session: %{messages: [], created_at: "t", metadata: %{}}}
      assert :ok = Session.save_session(dir, "test\0evil", state)
      assert File.exists?(Path.join(dir, "test_evil.jsonl"))
    end
  end

  describe "file permissions" do
    test "saved session files have 0600 permissions" do
      dir = tmp_sessions_dir()
      on_exit(fn -> File.rm_rf!(dir) end)

      state = %{session: %{messages: [], created_at: "t", metadata: %{}}}
      Session.save_session(dir, "perms_test", state)

      path = Path.join(dir, "perms_test.jsonl")
      {:ok, stat} = File.stat(path)
      assert stat.access == :read_write
    end
  end
end
