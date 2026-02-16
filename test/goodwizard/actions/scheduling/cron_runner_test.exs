defmodule Goodwizard.Actions.Scheduling.CronRunnerTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.CronRunner

  describe "concurrency limit" do
    test "returns error when at capacity" do
      alias Goodwizard.SubAgent

      pids =
        for i <- 1..3 do
          agent_id = "cron_limit_test:#{i}:#{System.unique_integer([:positive])}"
          {:ok, pid} = Goodwizard.Jido.start_agent(SubAgent, id: agent_id)
          pid
        end

      on_exit(fn ->
        Enum.each(pids, fn pid ->
          if Process.alive?(pid), do: Goodwizard.Jido.stop_agent(pid)
        end)
      end)

      assert {:error, :at_capacity} = CronRunner.run_isolated("test task", "room_xyz")
    end
  end

  describe "agent lifecycle" do
    test "spawns a SubAgent with model override in initial_state" do
      alias Goodwizard.SubAgent

      agent_id = "cron_model_test:#{System.unique_integer([:positive])}"
      opts = [id: agent_id, initial_state: %{model: "anthropic:claude-haiku-4-5"}]

      {:ok, pid} = Goodwizard.Jido.start_agent(SubAgent, opts)

      on_exit(fn ->
        if Process.alive?(pid), do: Goodwizard.Jido.stop_agent(pid)
      end)

      assert is_pid(pid)
      assert Process.alive?(pid)

      # Verify the agent accepted the initial_state (it started without error).
      # The model is stored in agent state and used by the ReAct strategy
      # at query time via Map.get(agent.state, :model, default).
      assert Process.alive?(pid)
    end

    test "spawns and stops agent correctly" do
      alias Goodwizard.SubAgent

      agent_id = "cron_lifecycle_test:#{System.unique_integer([:positive])}"
      {:ok, pid} = Goodwizard.Jido.start_agent(SubAgent, id: agent_id)

      assert Process.alive?(pid)
      Goodwizard.Jido.stop_agent(pid)
      Process.sleep(100)
      refute Process.alive?(pid)
    end
  end
end
