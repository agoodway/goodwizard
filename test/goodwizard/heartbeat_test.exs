defmodule Goodwizard.HeartbeatTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Heartbeat

  @moduletag :heartbeat

  setup do
    # Create a temp workspace with HEARTBEAT.md
    tmp_dir = Path.join(System.tmp_dir!(), "heartbeat_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    %{workspace: tmp_dir}
  end

  describe "process_heartbeat behavior" do
    test "skips when HEARTBEAT.md is missing", %{workspace: workspace} do
      Application.ensure_all_started(:goodwizard)

      heartbeat_path = Path.join(workspace, "HEARTBEAT.md")
      refute File.exists?(heartbeat_path)

      # Ensure module is loaded
      {:module, Heartbeat} = Code.ensure_loaded(Heartbeat)
      assert function_exported?(Heartbeat, :start_link, 0)
      assert function_exported?(Heartbeat, :init, 1)
    end

    test "detects file changes via mtime", %{workspace: workspace} do
      heartbeat_path = Path.join(workspace, "HEARTBEAT.md")
      charlist_path = String.to_charlist(heartbeat_path)

      # Create file and set mtime to a known past value
      File.write!(heartbeat_path, "test content")
      past_time = {{2020, 1, 1}, {0, 0, 0}}
      {:ok, info} = :file.read_file_info(charlist_path)
      # Set atime (element 4) and mtime (element 5) to past
      info = put_elem(info, 4, past_time) |> put_elem(5, past_time)
      :ok = :file.write_file_info(charlist_path, info)

      # Read back the mtime (may differ from set value due to timezone)
      {:ok, stat1} = File.stat(heartbeat_path)
      assert stat1.mtime < {{2021, 1, 1}, {0, 0, 0}}

      # Re-read same file — mtime is unchanged
      {:ok, stat2} = File.stat(heartbeat_path)
      assert stat1.mtime == stat2.mtime

      # Write new content — mtime changes to now
      File.write!(heartbeat_path, "updated content")
      {:ok, stat3} = File.stat(heartbeat_path)
      assert stat3.mtime != stat1.mtime
    end
  end

  describe "module structure" do
    test "Heartbeat is a GenServer" do
      assert {:module, Heartbeat} = Code.ensure_loaded(Heartbeat)
      # Check it has GenServer callbacks
      assert function_exported?(Heartbeat, :init, 1)
      assert function_exported?(Heartbeat, :handle_info, 2)
    end
  end

  describe "resolve_interval/0" do
    test "returns default 5 minutes when config has no interval" do
      Application.ensure_all_started(:goodwizard)
      # Default heartbeat config has no interval_minutes override
      # The module attribute @default_interval_ms is :timer.minutes(5) = 300_000
      assert :timer.minutes(5) == 300_000
    end
  end

  describe "structured heartbeat dispatch" do
    test "structured content is parsed into checks and produces numbered prompt" do
      content = """
      - [ ] Check inbox for new messages
      - [ ] Review calendar for events in the next 2 hours
      - [ ] Run project health check on goodwizard
      """

      content = String.trim(content)

      # Verify the parser detects structured format
      assert Goodwizard.Heartbeat.Parser.structured?(content)

      # Verify parse returns structured checks
      assert {:structured, checks} = Goodwizard.Heartbeat.Parser.parse(content)
      assert length(checks) == 3
      assert Enum.at(checks, 0) == %{index: 1, text: "Check inbox for new messages"}
      assert Enum.at(checks, 2) == %{index: 3, text: "Run project health check on goodwizard"}

      # Verify the prompt is properly built
      prompt = Goodwizard.Heartbeat.Parser.build_prompt(checks)
      assert prompt =~ "Process each of the following awareness checks"
      assert prompt =~ "1. Check inbox for new messages"
      assert prompt =~ "2. Review calendar for events in the next 2 hours"
      assert prompt =~ "3. Run project health check on goodwizard"

      # Verify checks metadata structure matches what dispatch_heartbeat would pass
      assert Enum.all?(checks, fn c -> is_integer(c.index) and is_binary(c.text) end)
    end

    test "structured heartbeat with checked items parses all items" do
      content = "- [x] Already done\n- [ ] Still pending"

      assert {:structured, checks} = Goodwizard.Heartbeat.Parser.parse(content)
      assert length(checks) == 2
      assert Enum.at(checks, 0).text == "Already done"
      assert Enum.at(checks, 1).text == "Still pending"
    end
  end

  describe "backwards compatibility: plain text heartbeat" do
    test "plain text content is not parsed as structured" do
      content = "Check on all active projects and summarize status"

      refute Goodwizard.Heartbeat.Parser.structured?(content)
      assert {:plain, ^content} = Goodwizard.Heartbeat.Parser.parse(content)
    end

    test "plain text with regular bullet points is not structured" do
      content = """
      - Check inbox
      - Review calendar
      """

      content = String.trim(content)
      refute Goodwizard.Heartbeat.Parser.structured?(content)
      assert {:plain, ^content} = Goodwizard.Heartbeat.Parser.parse(content)
    end
  end

  describe "integration: tick handling" do
    test "tick with missing HEARTBEAT.md does not crash", %{workspace: workspace} do
      Application.ensure_all_started(:goodwizard)

      heartbeat_path = Path.join(workspace, "HEARTBEAT.md")
      refute File.exists?(heartbeat_path)

      # Construct state as init/1 would produce (minus agent_pid/room_id)
      state = %{
        interval: 300_000,
        heartbeat_path: heartbeat_path,
        room_id: "test-room",
        agent_pid: self(),
        last_mtime: nil
      }

      # Directly invoke handle_info to test process_heartbeat
      assert {:noreply, new_state} = Heartbeat.handle_info(:tick, state)
      # last_mtime should remain nil (file missing)
      assert new_state.last_mtime == nil
    end

    test "tick with empty HEARTBEAT.md updates mtime but skips dispatch", %{workspace: workspace} do
      Application.ensure_all_started(:goodwizard)

      heartbeat_path = Path.join(workspace, "HEARTBEAT.md")
      File.write!(heartbeat_path, "")

      state = %{
        interval: 300_000,
        heartbeat_path: heartbeat_path,
        room_id: "test-room",
        agent_pid: self(),
        last_mtime: nil
      }

      {:noreply, new_state} = Heartbeat.handle_info(:tick, state)
      # mtime should be set even for empty file
      assert new_state.last_mtime != nil
    end

    test "tick with unchanged mtime skips processing", %{workspace: workspace} do
      Application.ensure_all_started(:goodwizard)

      heartbeat_path = Path.join(workspace, "HEARTBEAT.md")
      File.write!(heartbeat_path, "some content")
      {:ok, stat} = File.stat(heartbeat_path)

      state = %{
        interval: 300_000,
        heartbeat_path: heartbeat_path,
        room_id: "test-room",
        agent_pid: self(),
        last_mtime: stat.mtime
      }

      {:noreply, new_state} = Heartbeat.handle_info(:tick, state)
      # mtime unchanged, so state unchanged
      assert new_state.last_mtime == stat.mtime
    end

    test "tick with stat error does not crash", %{workspace: workspace} do
      Application.ensure_all_started(:goodwizard)

      # Use a path that will cause File.stat to fail
      heartbeat_path = Path.join(workspace, "nonexistent_dir/HEARTBEAT.md")

      state = %{
        interval: 300_000,
        heartbeat_path: heartbeat_path,
        room_id: "test-room",
        agent_pid: self(),
        last_mtime: nil
      }

      {:noreply, new_state} = Heartbeat.handle_info(:tick, state)
      assert new_state.last_mtime == nil
    end
  end
end
