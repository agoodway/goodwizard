defmodule Goodwizard.Scheduling.OneShotRegistryTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Scheduling.OneShotRegistry

  setup do
    # The registry is started in the app supervision tree.
    # Clear any state from previous tests by cancelling all known jobs.
    :ok
  end

  describe "register/2 and lookup/1" do
    test "registers and looks up a timer reference" do
      # Create a dummy timer ref
      {:ok, tref} = :timer.apply_after(60_000, fn -> :noop end)

      job_id = :"oneshot_reg_test_#{System.unique_integer([:positive])}"
      assert :ok = OneShotRegistry.register(job_id, tref)
      assert {:ok, ^tref} = OneShotRegistry.lookup(job_id)

      # Cleanup
      :timer.cancel(tref)
      OneShotRegistry.deregister(job_id)
    end

    test "lookup returns :error for unregistered job" do
      assert :error = OneShotRegistry.lookup(:"oneshot_missing_#{System.unique_integer([:positive])}")
    end

    test "overwrites existing registration" do
      {:ok, tref1} = :timer.apply_after(60_000, fn -> :noop end)
      {:ok, tref2} = :timer.apply_after(60_000, fn -> :noop end)

      job_id = :"oneshot_overwrite_#{System.unique_integer([:positive])}"
      OneShotRegistry.register(job_id, tref1)
      OneShotRegistry.register(job_id, tref2)

      assert {:ok, ^tref2} = OneShotRegistry.lookup(job_id)

      # Cleanup
      :timer.cancel(tref1)
      :timer.cancel(tref2)
      OneShotRegistry.deregister(job_id)
    end
  end

  describe "cancel/1" do
    test "cancels a registered timer and removes from registry" do
      {:ok, tref} = :timer.apply_after(60_000, fn -> :noop end)

      job_id = :"oneshot_cancel_#{System.unique_integer([:positive])}"
      OneShotRegistry.register(job_id, tref)

      assert :ok = OneShotRegistry.cancel(job_id)
      assert :error = OneShotRegistry.lookup(job_id)
    end

    test "returns :ok for unregistered job (idempotent)" do
      assert :ok = OneShotRegistry.cancel(:"oneshot_nope_#{System.unique_integer([:positive])}")
    end

    test "accepts string job_id" do
      {:ok, tref} = :timer.apply_after(60_000, fn -> :noop end)

      job_id = :"oneshot_strcancel_#{System.unique_integer([:positive])}"
      OneShotRegistry.register(job_id, tref)

      assert :ok = OneShotRegistry.cancel(to_string(job_id))
      assert :error = OneShotRegistry.lookup(job_id)
    end
  end

  describe "deregister/1" do
    test "removes entry without cancelling timer" do
      {:ok, tref} = :timer.apply_after(60_000, fn -> :noop end)

      job_id = :"oneshot_dereg_#{System.unique_integer([:positive])}"
      OneShotRegistry.register(job_id, tref)

      assert :ok = OneShotRegistry.deregister(job_id)
      assert :error = OneShotRegistry.lookup(job_id)

      # Timer should still be active (not cancelled)
      assert {:ok, :cancel} = :timer.cancel(tref)
    end

    test "returns :ok for unregistered job" do
      assert :ok = OneShotRegistry.deregister(:"oneshot_nothing_#{System.unique_integer([:positive])}")
    end
  end
end
