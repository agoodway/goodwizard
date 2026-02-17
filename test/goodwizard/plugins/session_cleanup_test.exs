defmodule Goodwizard.Plugins.SessionCleanupTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Plugins.Session

  setup do
    workspace =
      Path.join(System.tmp_dir!(), "gw_cleanup_test_#{System.unique_integer([:positive])}")

    sessions_dir = Path.join(workspace, "sessions")
    File.mkdir_p!(sessions_dir)

    # Point Config at our temp workspace
    original_workspace = Goodwizard.Config.get(["agent", "workspace"])
    Goodwizard.Config.put(["agent", "workspace"], workspace)

    on_exit(fn ->
      Goodwizard.Config.put(["agent", "workspace"], original_workspace)
      File.rm_rf!(workspace)
    end)

    {:ok, sessions_dir: sessions_dir}
  end

  describe "cleanup_old_sessions/0" do
    test "deletes oldest CLI sessions beyond retention limit", %{sessions_dir: sessions_dir} do
      Goodwizard.Config.put(["session", "max_cli_sessions"], 3)

      # Create 5 CLI session files with explicit staggered mtimes
      for i <- 1..5 do
        path = Path.join(sessions_dir, "cli-direct-100000#{i}.jsonl")
        File.write!(path, "{\"key\":\"cli-direct-100000#{i}\"}\n")
        # Set mtime with 1-minute increments so oldest = 1, newest = 5
        mtime = {{2026, 1, 1}, {0, i, 0}}
        File.touch!(path, mtime)
      end

      Session.cleanup_old_sessions()

      remaining = Path.wildcard(Path.join(sessions_dir, "cli-direct-*.jsonl")) |> Enum.sort()
      assert length(remaining) == 3

      # The 3 newest should survive (1000003, 1000004, 1000005)
      basenames = Enum.map(remaining, &Path.basename/1) |> Enum.sort()
      assert "cli-direct-1000003.jsonl" in basenames
      assert "cli-direct-1000004.jsonl" in basenames
      assert "cli-direct-1000005.jsonl" in basenames
    end

    test "does not delete when under limit", %{sessions_dir: sessions_dir} do
      Goodwizard.Config.put(["session", "max_cli_sessions"], 50)

      for i <- 1..5 do
        path = Path.join(sessions_dir, "cli-direct-200000#{i}.jsonl")
        File.write!(path, "{\"key\":\"test\"}\n")
      end

      Session.cleanup_old_sessions()

      remaining = Path.wildcard(Path.join(sessions_dir, "cli-direct-*.jsonl"))
      assert length(remaining) == 5
    end

    test "ignores non-CLI session files", %{sessions_dir: sessions_dir} do
      Goodwizard.Config.put(["session", "max_cli_sessions"], 2)

      # Create CLI files with explicit staggered mtimes
      for i <- 1..4 do
        path = Path.join(sessions_dir, "cli-direct-300000#{i}.jsonl")
        File.write!(path, "{\"key\":\"test\"}\n")
        File.touch!(path, {{2026, 1, 1}, {0, i, 0}})
      end

      # Create non-CLI files that should NOT be touched
      telegram_path = Path.join(sessions_dir, "telegram-12345.jsonl")
      File.write!(telegram_path, "{\"key\":\"telegram-12345\"}\n")

      default_path = Path.join(sessions_dir, "default.jsonl")
      File.write!(default_path, "{\"key\":\"default\"}\n")

      Session.cleanup_old_sessions()

      # Non-CLI files should still exist
      assert File.exists?(telegram_path)
      assert File.exists?(default_path)

      # Only 2 CLI files should remain
      cli_remaining = Path.wildcard(Path.join(sessions_dir, "cli-direct-*.jsonl"))
      assert length(cli_remaining) == 2
    end

    test "handles deletion errors gracefully", %{sessions_dir: sessions_dir} do
      Goodwizard.Config.put(["session", "max_cli_sessions"], 1)

      # Create 3 CLI files with explicit staggered mtimes
      for i <- 1..3 do
        path = Path.join(sessions_dir, "cli-direct-400000#{i}.jsonl")
        File.write!(path, "{\"key\":\"test\"}\n")
        File.touch!(path, {{2026, 1, 1}, {0, i, 0}})
      end

      # Replace the oldest file with a directory (File.rm will fail on a directory)
      oldest = Path.join(sessions_dir, "cli-direct-4000001.jsonl")
      File.rm!(oldest)
      File.mkdir_p!(oldest)
      # Set the directory's mtime to be oldest so it lands in the "delete" set
      File.touch!(oldest, {{2026, 1, 1}, {0, 0, 0}})

      # Should not crash despite failing to delete the directory
      assert :ok = Session.cleanup_old_sessions()

      # The directory "file" should still exist (deletion failed gracefully)
      assert File.exists?(oldest)

      # Clean up the directory we created
      File.rm_rf!(oldest)
    end

    test "returns :ok for empty sessions directory", %{sessions_dir: sessions_dir} do
      # sessions_dir exists but has no files
      assert [] = Path.wildcard(Path.join(sessions_dir, "cli-direct-*.jsonl"))
      assert :ok = Session.cleanup_old_sessions()
    end

    test "returns :ok when sessions directory does not exist" do
      # Point Config at a nonexistent workspace
      nonexistent =
        Path.join(System.tmp_dir!(), "gw_nonexistent_#{System.unique_integer([:positive])}")

      Goodwizard.Config.put(["agent", "workspace"], nonexistent)

      refute File.exists?(Path.join(nonexistent, "sessions"))
      assert :ok = Session.cleanup_old_sessions()
    end

    test "keeps all files when exactly at limit", %{sessions_dir: sessions_dir} do
      Goodwizard.Config.put(["session", "max_cli_sessions"], 3)

      for i <- 1..3 do
        path = Path.join(sessions_dir, "cli-direct-500000#{i}.jsonl")
        File.write!(path, "{\"key\":\"test\"}\n")
        File.touch!(path, {{2026, 1, 1}, {0, i, 0}})
      end

      Session.cleanup_old_sessions()

      remaining = Path.wildcard(Path.join(sessions_dir, "cli-direct-*.jsonl"))
      assert length(remaining) == 3
    end
  end
end
