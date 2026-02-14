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
  end
end
