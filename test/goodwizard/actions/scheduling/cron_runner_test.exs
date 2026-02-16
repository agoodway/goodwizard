defmodule Goodwizard.Actions.Scheduling.CronRunnerTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.CronRunner

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "cron_runner_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(@test_workspace)

    original_workspace = Goodwizard.Config.workspace()
    Goodwizard.Config.put(["agent", "workspace"], @test_workspace)

    on_exit(fn ->
      File.rm_rf!(@test_workspace)
      Goodwizard.Config.put(["agent", "workspace"], original_workspace)
    end)

    :ok
  end

  describe "run_isolated/3" do
    test "returns :at_capacity when max_concurrent_agents is 0" do
      # Set max to 0 so the capacity check triggers immediately
      Goodwizard.Config.put(["cron", "max_concurrent_agents"], 0)

      on_exit(fn ->
        Goodwizard.Config.put(["cron", "max_concurrent_agents"], nil)
      end)

      assert {:error, :at_capacity} = CronRunner.run_isolated("test task", "room_1")
    end

    test "accepts keyword opts for model override" do
      # Verify the function signature accepts opts — capacity will block actual execution
      Goodwizard.Config.put(["cron", "max_concurrent_agents"], 0)

      on_exit(fn ->
        Goodwizard.Config.put(["cron", "max_concurrent_agents"], nil)
      end)

      assert {:error, :at_capacity} =
               CronRunner.run_isolated("test task", "room_1", model: "anthropic:claude-haiku-4-5")
    end
  end
end
