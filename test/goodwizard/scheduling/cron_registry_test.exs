defmodule Goodwizard.Scheduling.CronRegistryTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Scheduling.CronRegistry

  describe "register/2 and lookup/1" do
    test "registers a pid and looks it up" do
      pid = spawn(fn -> Process.sleep(:infinity) end)
      job_id = :"cron_reg_test_#{System.unique_integer([:positive])}"

      assert :ok = CronRegistry.register(job_id, pid)
      assert {:ok, ^pid} = CronRegistry.lookup(job_id)
    end

    test "lookup returns :error for unknown job_id" do
      assert :error = CronRegistry.lookup(:cron_nonexistent_registry_test)
    end

    test "re-registering same job_id updates the pid" do
      pid1 = spawn(fn -> Process.sleep(:infinity) end)
      pid2 = spawn(fn -> Process.sleep(:infinity) end)
      job_id = :"cron_reg_retest_#{System.unique_integer([:positive])}"

      CronRegistry.register(job_id, pid1)
      CronRegistry.register(job_id, pid2)

      assert {:ok, ^pid2} = CronRegistry.lookup(job_id)
    end
  end

  describe "cancel/1" do
    test "cancels a registered job and removes it from registry" do
      # Use a long-lived process as a stand-in for a scheduler pid
      pid = spawn(fn -> Process.sleep(:infinity) end)
      job_id = :"cron_cancel_reg_#{System.unique_integer([:positive])}"

      CronRegistry.register(job_id, pid)
      assert {:ok, _} = CronRegistry.lookup(job_id)

      assert :ok = CronRegistry.cancel(job_id)
      assert :error = CronRegistry.lookup(job_id)
    end

    test "cancel is idempotent for unknown job_id" do
      assert :ok = CronRegistry.cancel(:cron_never_registered_test)
    end
  end

  describe "auto-cleanup on process death" do
    test "removes mapping when monitored process dies" do
      pid = spawn(fn -> Process.sleep(:infinity) end)
      job_id = :"cron_death_test_#{System.unique_integer([:positive])}"

      CronRegistry.register(job_id, pid)
      assert {:ok, ^pid} = CronRegistry.lookup(job_id)

      Process.exit(pid, :kill)
      # Give the GenServer time to process the :DOWN message
      Process.sleep(50)

      assert :error = CronRegistry.lookup(job_id)
    end
  end

  describe "string job_id normalization" do
    test "lookup normalizes string to existing atom" do
      pid = spawn(fn -> Process.sleep(:infinity) end)
      job_id = :"cron_str_test_#{System.unique_integer([:positive])}"

      CronRegistry.register(job_id, pid)
      assert {:ok, ^pid} = CronRegistry.lookup(to_string(job_id))
    end

    test "cancel normalizes string to existing atom" do
      pid = spawn(fn -> Process.sleep(:infinity) end)
      job_id = :"cron_str_cancel_#{System.unique_integer([:positive])}"

      CronRegistry.register(job_id, pid)
      assert :ok = CronRegistry.cancel(to_string(job_id))
      assert :error = CronRegistry.lookup(job_id)
    end
  end
end
