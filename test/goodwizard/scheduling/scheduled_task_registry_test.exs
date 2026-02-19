defmodule Goodwizard.Scheduling.ScheduledTaskRegistryTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Scheduling.ScheduledTaskRegistry

  setup do
    ensure_scheduled_task_registry_started()
    :ok
  end

  defp ensure_scheduled_task_registry_started do
    if Process.whereis(Goodwizard.Scheduling.ScheduledTaskRegistry) do
      :ok
    else
      start_supervised!(Goodwizard.Scheduling.ScheduledTaskRegistry)
      :ok
    end
  end

  describe "register/2 and lookup/1" do
    test "registers a pid and looks it up" do
      pid = spawn(fn -> Process.sleep(:infinity) end)
      job_id = :"scheduled_task_reg_test_#{System.unique_integer([:positive])}"

      assert :ok = ScheduledTaskRegistry.register(job_id, pid)
      assert {:ok, ^pid} = ScheduledTaskRegistry.lookup(job_id)
    end

    test "lookup returns :error for unknown job_id" do
      assert :error = ScheduledTaskRegistry.lookup(:scheduled_task_nonexistent_registry_test)
    end

    test "re-registering same job_id updates the pid" do
      pid1 = spawn(fn -> Process.sleep(:infinity) end)
      pid2 = spawn(fn -> Process.sleep(:infinity) end)
      job_id = :"scheduled_task_reg_retest_#{System.unique_integer([:positive])}"

      ScheduledTaskRegistry.register(job_id, pid1)
      ScheduledTaskRegistry.register(job_id, pid2)

      assert {:ok, ^pid2} = ScheduledTaskRegistry.lookup(job_id)
    end
  end

  describe "cancel/1" do
    test "cancels a registered job and removes it from registry" do
      # Use a long-lived process as a stand-in for a scheduler pid
      pid = spawn(fn -> Process.sleep(:infinity) end)
      job_id = :"scheduled_task_cancel_reg_#{System.unique_integer([:positive])}"

      ScheduledTaskRegistry.register(job_id, pid)
      assert {:ok, _} = ScheduledTaskRegistry.lookup(job_id)

      assert :ok = ScheduledTaskRegistry.cancel(job_id)
      assert :error = ScheduledTaskRegistry.lookup(job_id)
    end

    test "cancel is idempotent for unknown job_id" do
      assert :ok = ScheduledTaskRegistry.cancel(:scheduled_task_never_registered_test)
    end

    test "cancel handles dead pid without crashing registry" do
      pid = spawn(fn -> :ok end)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

      job_id = :scheduled_task_dead_pid_cancel
      ScheduledTaskRegistry.register(job_id, pid)

      assert :ok = ScheduledTaskRegistry.cancel(job_id)
      assert :error = ScheduledTaskRegistry.lookup(job_id)
    end
  end

  describe "auto-cleanup on process death" do
    test "removes mapping when monitored process dies" do
      pid = spawn(fn -> Process.sleep(:infinity) end)
      job_id = :"scheduled_task_death_test_#{System.unique_integer([:positive])}"

      ScheduledTaskRegistry.register(job_id, pid)
      assert {:ok, ^pid} = ScheduledTaskRegistry.lookup(job_id)

      Process.exit(pid, :kill)
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, reason} when reason in [:killed, :noproc]
      _ = :sys.get_state(ScheduledTaskRegistry)

      assert :error = ScheduledTaskRegistry.lookup(job_id)
    end
  end

  describe "string job_id normalization" do
    test "lookup normalizes string to existing atom" do
      pid = spawn(fn -> Process.sleep(:infinity) end)
      job_id = :"scheduled_task_str_test_#{System.unique_integer([:positive])}"

      ScheduledTaskRegistry.register(job_id, pid)
      assert {:ok, ^pid} = ScheduledTaskRegistry.lookup(to_string(job_id))
    end

    test "cancel normalizes string to existing atom" do
      pid = spawn(fn -> Process.sleep(:infinity) end)
      job_id = :"scheduled_task_str_cancel_#{System.unique_integer([:positive])}"

      ScheduledTaskRegistry.register(job_id, pid)
      assert :ok = ScheduledTaskRegistry.cancel(to_string(job_id))
      assert :error = ScheduledTaskRegistry.lookup(job_id)
    end
  end
end
