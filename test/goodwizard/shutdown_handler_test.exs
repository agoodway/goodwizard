defmodule Goodwizard.ShutdownHandlerTest do
  use ExUnit.Case, async: false

  alias Goodwizard.ShutdownHandler

  @moduletag :shutdown

  describe "ShutdownHandler" do
    test "starts and traps exits" do
      Application.ensure_all_started(:goodwizard)

      # ShutdownHandler should be running as part of the supervision tree
      pid = Process.whereis(ShutdownHandler)
      assert pid != nil
      assert Process.alive?(pid)
    end

    test "is a GenServer with correct callbacks" do
      assert {:module, ShutdownHandler} = Code.ensure_loaded(ShutdownHandler)
      assert function_exported?(ShutdownHandler, :init, 1)
      assert function_exported?(ShutdownHandler, :terminate, 2)
    end

    test "can be started standalone" do
      # Start in isolation
      {:ok, pid} = GenServer.start(ShutdownHandler, [])
      assert Process.alive?(pid)
      GenServer.stop(pid, :normal)
    end

    test "terminate/2 completes without error when no agents running" do
      # Start a standalone handler
      {:ok, pid} = GenServer.start(ShutdownHandler, [])

      # Stopping should invoke terminate and complete gracefully
      assert GenServer.stop(pid, :normal) == :ok
    end
  end

  describe "flush_sessions" do
    test "terminate handles Jido.list_agents raising an error gracefully" do
      import ExUnit.CaptureLog

      {:ok, pid} = GenServer.start(ShutdownHandler, [])

      log =
        capture_log(fn ->
          # Stopping triggers terminate which calls flush_sessions
          # If Jido isn't running, list_agents will fail — the rescue should catch it
          GenServer.stop(pid, :normal)
        end)

      # Should log the flush attempt
      assert log =~ "Flushing sessions"
    end

    test "terminate with :shutdown reason completes gracefully" do
      import ExUnit.CaptureLog

      {:ok, pid} = GenServer.start(ShutdownHandler, [])

      log =
        capture_log(fn ->
          GenServer.stop(pid, :shutdown)
        end)

      assert log =~ "Graceful shutdown initiated"
      assert log =~ "Graceful shutdown complete"
    end

    test "init traps exits so terminate is called" do
      {:ok, pid} = GenServer.start(ShutdownHandler, [])

      # Verify the process has trap_exit enabled
      {:trap_exit, trapping} = Process.info(pid, :trap_exit)
      assert trapping == true

      GenServer.stop(pid, :normal)
    end
  end
end
