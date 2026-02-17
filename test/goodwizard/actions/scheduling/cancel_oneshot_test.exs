defmodule Goodwizard.Actions.Scheduling.CancelOneShotTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.{CancelOneShot, OneShot}
  alias Goodwizard.Scheduling.{OneShotRegistry, OneShotStore}

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "cancel_oneshot_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    oneshot_dir = Path.join(@test_workspace, "scheduling/oneshot")
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(oneshot_dir)

    original_workspace = Goodwizard.Config.workspace()
    Goodwizard.Config.put(["agent", "workspace"], @test_workspace)

    on_exit(fn ->
      File.rm_rf!(@test_workspace)
      Goodwizard.Config.put(["agent", "workspace"], original_workspace)
    end)

    %{oneshot_dir: oneshot_dir}
  end

  describe "run/2" do
    test "cancels a pending one-shot job", %{oneshot_dir: oneshot_dir} do
      # Schedule a job first
      params = %{delay_minutes: 60, task: "cancel me", room_id: "cli:main"}
      assert {:ok, result} = OneShot.run(params, %{})

      job_id = result.job_id
      job_id_str = to_string(job_id)

      # Verify it exists
      assert File.exists?(Path.join(oneshot_dir, "#{job_id}.json"))
      assert {:ok, _tref} = OneShotRegistry.lookup(job_id)

      # Cancel it
      assert {:ok, %{cancelled: true, job_id: ^job_id}} =
               CancelOneShot.run(%{job_id: job_id_str}, %{})

      # Verify cleanup
      refute File.exists?(Path.join(oneshot_dir, "#{job_id}.json"))
      assert :error = OneShotRegistry.lookup(job_id)
    end

    test "cancelling already-fired job is idempotent" do
      # Use a job_id that doesn't exist (simulating already fired)
      assert {:ok, %{cancelled: true}} =
               CancelOneShot.run(%{job_id: "oneshot_doesnotexist00"}, %{})
    end

    test "cancelling with invalid job_id format still succeeds" do
      # Invalid format but should not crash — store.delete returns :ok for missing
      assert {:ok, %{cancelled: true}} =
               CancelOneShot.run(%{job_id: "oneshot_short"}, %{})
    end
  end
end
