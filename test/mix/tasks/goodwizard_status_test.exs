defmodule Mix.Tasks.Goodwizard.StatusTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @moduletag :mix_task

  describe "mix goodwizard.status" do
    test "prints configuration section" do
      Application.ensure_all_started(:goodwizard)

      output =
        capture_io(fn ->
          Mix.Tasks.Goodwizard.Status.run([])
        end)

      assert output =~ "=== Configuration ==="
      assert output =~ "Model:"
      assert output =~ "Workspace:"
      assert output =~ "Channels:"
    end

    test "prints messaging rooms section" do
      Application.ensure_all_started(:goodwizard)

      output =
        capture_io(fn ->
          Mix.Tasks.Goodwizard.Status.run([])
        end)

      assert output =~ "=== Messaging Rooms ==="
    end

    test "prints channel instances section" do
      Application.ensure_all_started(:goodwizard)

      output =
        capture_io(fn ->
          Mix.Tasks.Goodwizard.Status.run([])
        end)

      assert output =~ "=== Channel Instances ==="
    end

    test "prints memory stats section" do
      Application.ensure_all_started(:goodwizard)

      output =
        capture_io(fn ->
          Mix.Tasks.Goodwizard.Status.run([])
        end)

      assert output =~ "=== Memory Stats ==="
      assert output =~ "Sessions:"
      assert output =~ "Workspace:"
    end
  end
end
