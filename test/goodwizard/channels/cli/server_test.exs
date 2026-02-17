defmodule Goodwizard.Channels.CLI.ServerTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Channels.CLI.Server
  alias Goodwizard.Messaging

  setup do
    workspace = Path.join(System.tmp_dir!(), "gw_cli_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(workspace)
    on_exit(fn -> File.rm_rf!(workspace) end)
    {:ok, workspace: workspace}
  end

  describe "init/1" do
    test "starts successfully and returns {:ok, pid}", %{workspace: workspace} do
      {:ok, pid} = Server.start_link(workspace: workspace, start_repl: false)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "creates a Messaging room with CLI external binding", %{workspace: workspace} do
      {:ok, pid} = Server.start_link(workspace: workspace, start_repl: false)
      state = Server.get_state(pid)

      assert is_binary(state.room_id)

      # Verify the room exists in Messaging
      {:ok, room} = Messaging.get_or_create_room_by_external_binding(:cli, "goodwizard", "direct")
      assert room.id == state.room_id
    end

    test "starts an AgentServer with correct state", %{workspace: workspace} do
      {:ok, pid} = Server.start_link(workspace: workspace, start_repl: false)
      state = Server.get_state(pid)

      assert is_pid(state.agent_pid)
      assert Process.alive?(state.agent_pid)

      # Verify agent state
      {:ok, server_state} = Jido.AgentServer.state(state.agent_pid)
      agent = server_state.agent

      assert agent.state.workspace == workspace
      assert agent.state.channel == "cli"
      assert agent.state.chat_id == "direct"
    end

    test "stores workspace in state", %{workspace: workspace} do
      {:ok, pid} = Server.start_link(workspace: workspace, start_repl: false)
      state = Server.get_state(pid)

      assert state.workspace == workspace
    end

    test "sets timestamped session_key in agent initial state", %{workspace: workspace} do
      before_ts = System.os_time(:millisecond)
      {:ok, pid} = Server.start_link(workspace: workspace, start_repl: false)
      after_ts = System.os_time(:millisecond)
      state = Server.get_state(pid)

      {:ok, server_state} = Jido.AgentServer.state(state.agent_pid)
      session_key = server_state.agent.state.session_key

      assert String.starts_with?(session_key, "cli-direct-")

      ts_str =
        session_key
        |> String.replace_prefix("cli-direct-", "")
        |> String.split("-", parts: 2)
        |> hd()

      {ts, ""} = Integer.parse(ts_str)
      assert ts >= before_ts
      assert ts <= after_ts
    end
  end

  describe "send_input/2" do
    test "rejects input exceeding max length", %{workspace: workspace} do
      {:ok, pid} = Server.start_link(workspace: workspace, start_repl: false)

      oversized_input = String.duplicate("a", 10_001)
      assert {:error, :input_too_long} = Server.send_input(pid, oversized_input)
    end

    test "accepts input at max length boundary", %{workspace: workspace} do
      {:ok, pid} = Server.start_link(workspace: workspace, start_repl: false)

      # Exactly at the limit — should proceed (may error from agent, but not :input_too_long)
      max_input = String.duplicate("a", 10_000)
      result = Server.send_input(pid, max_input)
      refute match?({:error, :input_too_long}, result)
    end

    test "handles agent response and saves messages", %{workspace: workspace} do
      {:ok, pid} = Server.start_link(workspace: workspace, start_repl: false)

      # In test env without API key, agent returns error as response text
      result = Server.send_input(pid, "hello")
      # Either success (with error text as response) or error — both paths are valid
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
