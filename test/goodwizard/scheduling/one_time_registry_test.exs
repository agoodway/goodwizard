defmodule Goodwizard.Scheduling.OneTimeRegistryTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Scheduling.OneTimeRegistry

  setup do
    # The registry is started in the app supervision tree.
    # Clear any state from previous tests by cancelling all known jobs.
    :ok
  end

  describe "register/2 and lookup/1" do
    test "registers and looks up a timer reference" do
      # Create a dummy timer ref
      {:ok, tref} = :timer.apply_after(60_000, fn -> :noop end)

      job_id = :"one_time_reg_test_#{System.unique_integer([:positive])}"
      assert :ok = OneTimeRegistry.register(job_id, tref)
      assert {:ok, ^tref} = OneTimeRegistry.lookup(job_id)

      # Cleanup
      :timer.cancel(tref)
      OneTimeRegistry.deregister(job_id)
    end

    test "lookup returns :error for unregistered job" do
      assert :error =
               OneTimeRegistry.lookup(:"one_time_missing_#{System.unique_integer([:positive])}")
    end

    test "overwrites existing registration" do
      {:ok, tref1} = :timer.apply_after(60_000, fn -> :noop end)
      {:ok, tref2} = :timer.apply_after(60_000, fn -> :noop end)

      job_id = :"one_time_overwrite_#{System.unique_integer([:positive])}"
      OneTimeRegistry.register(job_id, tref1)
      OneTimeRegistry.register(job_id, tref2)

      assert {:ok, ^tref2} = OneTimeRegistry.lookup(job_id)

      # Cleanup
      :timer.cancel(tref1)
      :timer.cancel(tref2)
      OneTimeRegistry.deregister(job_id)
    end
  end

  describe "cancel/1" do
    test "cancels a registered timer and removes from registry" do
      {:ok, tref} = :timer.apply_after(60_000, fn -> :noop end)

      job_id = :"one_time_cancel_#{System.unique_integer([:positive])}"
      OneTimeRegistry.register(job_id, tref)

      assert :ok = OneTimeRegistry.cancel(job_id)
      assert :error = OneTimeRegistry.lookup(job_id)
    end

    test "returns :ok for unregistered job (idempotent)" do
      assert :ok = OneTimeRegistry.cancel(:"one_time_nope_#{System.unique_integer([:positive])}")
    end

    test "accepts string job_id" do
      {:ok, tref} = :timer.apply_after(60_000, fn -> :noop end)

      job_id = :"one_time_strcancel_#{System.unique_integer([:positive])}"
      OneTimeRegistry.register(job_id, tref)

      assert :ok = OneTimeRegistry.cancel(to_string(job_id))
      assert :error = OneTimeRegistry.lookup(job_id)
    end
  end

  describe "deregister/1" do
    test "removes entry without cancelling timer" do
      {:ok, tref} = :timer.apply_after(60_000, fn -> :noop end)

      job_id = :"one_time_dereg_#{System.unique_integer([:positive])}"
      OneTimeRegistry.register(job_id, tref)

      assert :ok = OneTimeRegistry.deregister(job_id)
      assert :error = OneTimeRegistry.lookup(job_id)

      # Timer should still be active (not cancelled)
      assert {:ok, :cancel} = :timer.cancel(tref)
    end

    test "returns :ok for unregistered job" do
      assert :ok =
               OneTimeRegistry.deregister(
                 :"one_time_nothing_#{System.unique_integer([:positive])}"
               )
    end
  end
end
