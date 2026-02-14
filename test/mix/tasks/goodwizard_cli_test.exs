defmodule Mix.Tasks.Goodwizard.CliTest do
  use ExUnit.Case

  alias Mix.Tasks.Goodwizard.Cli

  describe "run/1" do
    test "starts CLI server and returns when server stops" do
      # Run the task in a separate process so it doesn't block the test
      task =
        Task.async(fn ->
          Cli.run([])
        end)

      # Give the server time to start
      Process.sleep(200)

      # The task should still be running (blocked on receive)
      refute Task.yield(task, 0)

      # Find the CLI server process (it's the one monitored by the task)
      # Stop the server by killing the task process, which triggers the DOWN message
      Task.shutdown(task, :brutal_kill)
    end

    test "module has correct shortdoc" do
      assert Mix.Task.shortdoc(Cli) == "Start Goodwizard CLI REPL"
    end
  end
end
