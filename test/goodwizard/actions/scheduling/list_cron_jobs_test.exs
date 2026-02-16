defmodule Goodwizard.Actions.Scheduling.ListCronJobsTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.ListCronJobs
  alias Goodwizard.Scheduling.CronStore

  @test_workspace Path.join(System.tmp_dir!(), "list_cron_test_#{System.unique_integer([:positive])}")

  setup do
    cron_dir = Path.join(@test_workspace, "scheduling/cron")
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(cron_dir)

    System.put_env("GOODWIZARD_WORKSPACE", @test_workspace)

    if Process.whereis(Goodwizard.Config) do
      GenServer.stop(Goodwizard.Config)
      Goodwizard.Config.start_link([])
    end

    on_exit(fn ->
      File.rm_rf!(@test_workspace)
      System.delete_env("GOODWIZARD_WORKSPACE")

      if Process.whereis(Goodwizard.Config) do
        GenServer.stop(Goodwizard.Config)
        Goodwizard.Config.start_link([])
      end
    end)

    %{cron_dir: cron_dir}
  end

  describe "run/2" do
    test "returns persisted job records" do
      CronStore.save(%{
        job_id: :cron_list1,
        schedule: "0 9 * * *",
        task: "morning check",
        room_id: "cli:main",
        created_at: "2026-02-15T00:00:00Z"
      })

      CronStore.save(%{
        job_id: :cron_list2,
        schedule: "*/5 * * * *",
        task: "poll status",
        room_id: "cli:heartbeat",
        created_at: "2026-02-15T01:00:00Z"
      })

      assert {:ok, result} = ListCronJobs.run(%{}, %{})
      assert result.count == 2
      assert length(result.jobs) == 2

      job_ids = Enum.map(result.jobs, & &1["job_id"]) |> Enum.sort()
      assert "cron_list1" in job_ids
      assert "cron_list2" in job_ids
    end

    test "returns empty list when no jobs exist" do
      assert {:ok, result} = ListCronJobs.run(%{}, %{})
      assert result.jobs == []
      assert result.count == 0
    end

    test "each job record contains expected fields" do
      CronStore.save(%{
        job_id: :cron_fields,
        schedule: "@daily",
        task: "daily report",
        room_id: "cli:main",
        mode: "isolated",
        created_at: "2026-02-15T00:00:00Z"
      })

      assert {:ok, result} = ListCronJobs.run(%{}, %{})
      [job] = result.jobs

      assert job["job_id"] == "cron_fields"
      assert job["schedule"] == "@daily"
      assert job["task"] == "daily report"
      assert job["room_id"] == "cli:main"
      assert job["created_at"] == "2026-02-15T00:00:00Z"
    end

    test "returns empty list when directory doesn't exist" do
      cron_dir = Path.join(@test_workspace, "scheduling/cron")
      File.rm_rf!(cron_dir)

      assert {:ok, result} = ListCronJobs.run(%{}, %{})
      assert result.jobs == []
      assert result.count == 0
    end
  end
end
