defmodule Mix.Tasks.Goodwizard.ScenarioTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Goodwizard.Scenario

  test "list command prints shipped scenarios with descriptions" do
    output =
      capture_io(fn ->
        Scenario.run(["list"])
      end)

    assert output =~ "smoke_test"
    assert output =~ "memory_continuity"
    assert output =~ "Basic single-turn sanity check"
    assert output =~ "Two-turn memory continuity check"
  end
end
