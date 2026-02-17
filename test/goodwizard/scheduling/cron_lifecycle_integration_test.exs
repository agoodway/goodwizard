defmodule Goodwizard.Scheduling.CronLifecycleIntegrationTest do
  @moduledoc """
  Integration test for the full cron lifecycle:
  schedule -> persist -> reload -> cancel
  """
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.{Cron, CancelCron}
  alias Goodwizard.Scheduling.{CronStore, CronLoader}

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "cron_lifecycle_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    cron_dir = Path.join(@test_workspace, "scheduling/cron")
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(cron_dir)

    original_workspace = Goodwizard.Config.workspace()
    Goodwizard.Config.put(["agent", "workspace"], @test_workspace)

    on_exit(fn ->
      File.rm_rf!(@test_workspace)
      Goodwizard.Config.put(["agent", "workspace"], original_workspace)
    end)

    %{cron_dir: cron_dir}
  end

  test "full lifecycle: schedule, persist, list, reload, cancel", %{cron_dir: cron_dir} do
    # 1. Schedule a cron job
    params = %{schedule: "0 9 * * *", task: "lifecycle test", room_id: "room_lifecycle"}
    assert {:ok, result} = Cron.run(params, %{})
    assert result.scheduled == true
    job_id = result.job_id
    job_id_str = to_string(job_id)

    # 2. Verify persistence
    path = Path.join(cron_dir, "#{job_id_str}.json")
    assert File.exists?(path)

    # 3. Verify listing
    assert {:ok, jobs} = CronStore.list()
    assert length(jobs) == 1
    assert hd(jobs)["job_id"] == job_id_str

    # 4. Reload from disk (simulating app restart)
    assert {:ok, count} = CronLoader.reload()
    assert count == 1

    # 5. Cancel the job
    assert {:ok, cancel_result} = CancelCron.run(%{job_id: job_id_str}, %{})
    assert cancel_result.cancelled == true

    # 6. Verify file deleted
    refute File.exists?(path)

    # 7. Verify listing is empty
    assert {:ok, []} = CronStore.list()
  end

  test "scheduling multiple jobs and cancelling one preserves others" do
    # Schedule two jobs
    assert {:ok, r1} = Cron.run(%{schedule: "0 9 * * *", task: "job one", room_id: "room_1"}, %{})

    assert {:ok, r2} =
             Cron.run(%{schedule: "0 10 * * *", task: "job two", room_id: "room_1"}, %{})

    assert {:ok, jobs} = CronStore.list()
    assert length(jobs) == 2

    # Cancel one
    CancelCron.run(%{job_id: to_string(r1.job_id)}, %{})

    # Other is preserved
    assert {:ok, remaining} = CronStore.list()
    assert length(remaining) == 1
    assert hd(remaining)["job_id"] == to_string(r2.job_id)
  end
end
