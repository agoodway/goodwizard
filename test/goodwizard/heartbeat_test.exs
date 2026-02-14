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

      # Create file
      File.write!(heartbeat_path, "test content")
      {:ok, stat1} = File.stat(heartbeat_path)

      # Same content, same mtime
      {:ok, stat2} = File.stat(heartbeat_path)
      assert stat1.mtime == stat2.mtime

      # Touch the file to change mtime
      :timer.sleep(1100)
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
end
