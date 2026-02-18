defmodule Goodwizard.Actions.Scheduling.CancelOneTimeTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.{CancelOneTime, OneTime}
  alias Goodwizard.Scheduling.OneTimeRegistry

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "cancel_one_time_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    ensure_goodwizard_started()
    ensure_config_started()
    ensure_one_time_registry_started()

    one_time_dir = Path.join(@test_workspace, "scheduling/one_time")
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(one_time_dir)

    original_workspace = Goodwizard.Config.workspace()
    Goodwizard.Config.put(["agent", "workspace"], @test_workspace)

    on_exit(fn ->
      File.rm_rf!(@test_workspace)

      if Process.whereis(Goodwizard.Config) do
        Goodwizard.Config.put(["agent", "workspace"], original_workspace)
      end
    end)

    %{one_time_dir: one_time_dir}
  end

  defp ensure_config_started do
    if Process.whereis(Goodwizard.Config) do
      :ok
    else
      start_supervised!(Goodwizard.Config)
      :ok
    end
  end

  defp ensure_goodwizard_started do
    case Application.ensure_all_started(:goodwizard) do
      {:ok, _apps} -> :ok
      {:error, reason} -> raise "failed to start :goodwizard for test: #{inspect(reason)}"
    end
  end

  defp ensure_one_time_registry_started do
    if Process.whereis(Goodwizard.Scheduling.OneTimeRegistry) do
      :ok
    else
      start_supervised!(Goodwizard.Scheduling.OneTimeRegistry)
      :ok
    end
  end

  describe "run/2" do
    test "cancels a pending one-time task", %{one_time_dir: one_time_dir} do
      # Schedule a job first
      params = %{delay_minutes: 60, task: "cancel me", channel: "cli", external_id: "direct"}
      assert {:ok, result} = OneTime.run(params, %{})

      job_id = result.job_id
      job_id_str = to_string(job_id)

      # Verify it exists
      assert File.exists?(Path.join(one_time_dir, "#{job_id}.json"))
      assert {:ok, _tref} = OneTimeRegistry.lookup(job_id)

      # Cancel it
      assert {:ok, %{cancelled: true, job_id: ^job_id_str}} =
               CancelOneTime.run(%{job_id: job_id_str}, %{})

      # Verify cleanup
      refute File.exists?(Path.join(one_time_dir, "#{job_id}.json"))
      assert :error = OneTimeRegistry.lookup(job_id)
    end

    test "cancelling already-fired job is idempotent" do
      # Use a job_id that doesn't exist (simulating already fired)
      assert {:ok, %{cancelled: true}} =
               CancelOneTime.run(%{job_id: "one_time_doesnotexist00"}, %{})
    end

    test "cancelling with invalid job_id format still succeeds" do
      # Invalid format but should not crash — store.delete returns :ok for missing
      assert {:ok, %{cancelled: true}} =
               CancelOneTime.run(%{job_id: "one_time_short"}, %{})
    end
  end
end
