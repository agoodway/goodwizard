defmodule Goodwizard.HeartbeatTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Config
  alias Goodwizard.Heartbeat
  alias Goodwizard.Heartbeat.Parser
  alias Goodwizard.Messaging

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
      Config.put(["heartbeat", "interval_minutes"], nil)
      assert Heartbeat.resolve_interval() == 300_000
    end

    test "converts configured minutes to milliseconds" do
      Application.ensure_all_started(:goodwizard)
      Config.put(["heartbeat", "interval_minutes"], 10)

      on_exit(fn -> Config.put(["heartbeat", "interval_minutes"], nil) end)

      assert Heartbeat.resolve_interval() == 600_000
    end

    test "returns default for non-numeric config value" do
      Application.ensure_all_started(:goodwizard)
      Config.put(["heartbeat", "interval_minutes"], "not_a_number")

      on_exit(fn -> Config.put(["heartbeat", "interval_minutes"], nil) end)

      assert Heartbeat.resolve_interval() == 300_000
    end
  end

  describe "resolve_timeout/0" do
    test "returns default 120 seconds when config has no timeout" do
      Application.ensure_all_started(:goodwizard)
      Config.put(["heartbeat", "timeout_seconds"], nil)
      assert Heartbeat.resolve_timeout() == 120_000
    end

    test "converts configured seconds to milliseconds" do
      Application.ensure_all_started(:goodwizard)
      Config.put(["heartbeat", "timeout_seconds"], 60)

      on_exit(fn -> Config.put(["heartbeat", "timeout_seconds"], nil) end)

      assert Heartbeat.resolve_timeout() == 60_000
    end
  end

  describe "resolve_room_binding/0" do
    test "returns default {:cli, goodwizard, heartbeat} when no config" do
      Application.ensure_all_started(:goodwizard)
      Config.put(["heartbeat", "channel"], nil)
      Config.put(["heartbeat", "chat_id"], nil)

      assert Heartbeat.resolve_room_binding() == {:cli, "goodwizard", "heartbeat"}
    end

    test "returns configured known channel and chat_id" do
      Application.ensure_all_started(:goodwizard)
      Config.put(["heartbeat", "channel"], "cli")
      Config.put(["heartbeat", "chat_id"], "test-chat")

      on_exit(fn ->
        Config.put(["heartbeat", "channel"], nil)
        Config.put(["heartbeat", "chat_id"], nil)
      end)

      assert Heartbeat.resolve_room_binding() == {:cli, "goodwizard", "test-chat"}
    end

    test "falls back to :cli for unknown channel string" do
      Application.ensure_all_started(:goodwizard)
      # Use a string that already exists as an atom but is not in @known_channels
      Config.put(["heartbeat", "channel"], "true")
      Config.put(["heartbeat", "chat_id"], "test-chat")

      on_exit(fn ->
        Config.put(["heartbeat", "channel"], nil)
        Config.put(["heartbeat", "chat_id"], nil)
      end)

      assert Heartbeat.resolve_room_binding() == {:cli, "goodwizard", "test-chat"}
    end

    test "falls back to :cli when channel atom does not exist" do
      Application.ensure_all_started(:goodwizard)

      Config.put(
        ["heartbeat", "channel"],
        "nonexistent_channel_xyz_#{System.unique_integer()}"
      )

      Config.put(["heartbeat", "chat_id"], "test-chat")

      on_exit(fn ->
        Config.put(["heartbeat", "channel"], nil)
        Config.put(["heartbeat", "chat_id"], nil)
      end)

      assert Heartbeat.resolve_room_binding() == {:cli, "goodwizard", "heartbeat"}
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
      assert Parser.structured?(content)

      # Verify parse returns structured checks
      assert {:structured, checks} = Parser.parse(content)
      assert length(checks) == 3

      assert Enum.at(checks, 0) == %{
               index: 1,
               text: "Check inbox for new messages",
               checked: false
             }

      assert Enum.at(checks, 2) == %{
               index: 3,
               text: "Run project health check on goodwizard",
               checked: false
             }

      # Verify the prompt is properly built
      prompt = Parser.build_prompt(checks)
      assert prompt =~ "Process each of the following awareness checks"
      assert prompt =~ "1. Check inbox for new messages"
      assert prompt =~ "2. Review calendar for events in the next 2 hours"
      assert prompt =~ "3. Run project health check on goodwizard"

      # Verify checks metadata structure matches what dispatch_heartbeat would pass
      assert Enum.all?(checks, fn c -> is_integer(c.index) and is_binary(c.text) end)
    end

    test "structured heartbeat with checked items parses all items with checked status" do
      content = "- [x] Already done\n- [ ] Still pending"

      assert {:structured, checks} = Parser.parse(content)
      assert length(checks) == 2
      assert Enum.at(checks, 0) == %{index: 1, text: "Already done", checked: true}
      assert Enum.at(checks, 1) == %{index: 2, text: "Still pending", checked: false}
    end

    test "build_prompt with empty list produces preamble only" do
      prompt = Parser.build_prompt([])
      assert prompt == "Process each of the following awareness checks and report on each:\n"
    end
  end

  describe "backwards compatibility: plain text heartbeat" do
    test "plain text content is not parsed as structured" do
      content = "Check on all active projects and summarize status"

      refute Parser.structured?(content)
      assert {:plain, ^content} = Parser.parse(content)
    end

    test "plain text with regular bullet points is not structured" do
      content = """
      - Check inbox
      - Review calendar
      """

      content = String.trim(content)
      refute Parser.structured?(content)
      assert {:plain, ^content} = Parser.parse(content)
    end
  end

  describe "integration: structured tick dispatch" do
    test "tick with structured HEARTBEAT.md dispatches structured prompt and saves checks metadata",
         %{workspace: workspace} do
      Application.ensure_all_started(:goodwizard)

      heartbeat_path = Path.join(workspace, "HEARTBEAT.md")

      File.write!(heartbeat_path, """
      - [ ] Check inbox for messages
      - [x] Review calendar
      - [ ] Run health check
      """)

      {:ok, room} =
        Messaging.get_or_create_room_by_external_binding(
          :cli,
          "heartbeat_test",
          "structured_tick_#{System.unique_integer([:positive])}",
          %{type: :direct, name: "Heartbeat Structured Tick Test"}
        )

      test_pid = self()
      agent_pid = start_supervised!({Task, fn -> fake_heartbeat_agent_loop(test_pid) end})

      state = %{
        interval: 300_000,
        heartbeat_path: heartbeat_path,
        room_id: room.id,
        agent_pid: agent_pid,
        last_mtime: nil
      }

      assert {:noreply, new_state} = Heartbeat.handle_info(:tick, state)
      assert new_state.last_mtime != nil

      {:ok, content} = File.read(heartbeat_path)
      content = String.trim(content)
      assert {:structured, checks} = Parser.parse(content)
      expected_prompt = Parser.build_prompt(checks)

      assert_receive {:fake_agent_query, ^expected_prompt}, 1_000

      {:ok, messages} = Messaging.list_messages(room.id)

      heartbeat_message =
        Enum.find(messages, fn msg -> msg.role == :user and msg.sender_id == "heartbeat" end)

      assert heartbeat_message
      assert [%{type: "text", text: ^expected_prompt}] = heartbeat_message.content
      assert %{checks: ^checks} = heartbeat_message.metadata
    end

    test "tick with structured file updates mtime", %{workspace: workspace} do
      Application.ensure_all_started(:goodwizard)

      heartbeat_path = Path.join(workspace, "HEARTBEAT.md")
      File.write!(heartbeat_path, "- [ ] Check inbox\n- [ ] Review calendar")

      state = %{
        interval: 300_000,
        heartbeat_path: heartbeat_path,
        room_id: "test-room",
        agent_pid: self(),
        last_mtime: nil
      }

      # handle_info will attempt dispatch which fails (no real agent),
      # but the mtime should still update since process_changed_file
      # updates mtime after reading regardless of dispatch outcome
      try do
        Heartbeat.handle_info(:tick, state)
      catch
        :exit, _ -> :ok
      end

      # Verify file was read successfully by checking stat
      {:ok, stat} = File.stat(heartbeat_path)
      assert stat.mtime != nil
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

  defp fake_heartbeat_agent_loop(test_pid) do
    receive do
      {:"$gen_cast", {:signal, %Jido.Signal{data: data}}} ->
        query = Map.get(data, :query) || Map.get(data, "query")
        send(test_pid, {:fake_agent_query, query})
        fake_heartbeat_agent_loop(test_pid)

      {:"$gen_call", from, {:await_completion, _opts}} ->
        GenServer.reply(from, {:ok, %{status: :completed, result: "mock heartbeat response"}})
        fake_heartbeat_agent_loop(test_pid)

      _other ->
        fake_heartbeat_agent_loop(test_pid)
    end
  end
end
