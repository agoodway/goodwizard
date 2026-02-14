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
end
