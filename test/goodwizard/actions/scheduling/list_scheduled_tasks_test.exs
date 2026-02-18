defmodule Goodwizard.Actions.Scheduling.ListScheduledTasksTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.ListScheduledTasks
  alias Goodwizard.Scheduling.ScheduledTaskStore

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "list_scheduled_task_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    ensure_config_started()

    scheduled_task_dir = Path.join(@test_workspace, "scheduling/scheduled_tasks")
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(scheduled_task_dir)

    # Save original workspace and override it for tests
    original_workspace = Goodwizard.Config.workspace()
    Goodwizard.Config.put(["agent", "workspace"], @test_workspace)

    on_exit(fn ->
      File.rm_rf!(@test_workspace)

      if Process.whereis(Goodwizard.Config) do
        Goodwizard.Config.put(["agent", "workspace"], original_workspace)
      end
    end)

    %{scheduled_task_dir: scheduled_task_dir}
  end

  defp ensure_config_started do
    if Process.whereis(Goodwizard.Config) do
      :ok
    else
      start_supervised!(Goodwizard.Config)
      :ok
    end
  end

  describe "run/2" do
    test "returns persisted job records" do
      ScheduledTaskStore.save(%{
        job_id: :scheduled_task_list1,
        schedule: "0 9 * * *",
        task: "morning check",
        room_id: "cli:main",
        created_at: "2026-02-15T00:00:00Z"
      })

      ScheduledTaskStore.save(%{
        job_id: :scheduled_task_list2,
        schedule: "*/5 * * * *",
        task: "poll status",
        room_id: "cli:heartbeat",
        created_at: "2026-02-15T01:00:00Z"
      })

      assert {:ok, result} = ListScheduledTasks.run(%{}, %{})
      assert result.count == 2
      assert length(result.jobs) == 2

      job_ids = Enum.map(result.jobs, & &1["job_id"]) |> Enum.sort()
      assert "scheduled_task_list1" in job_ids
      assert "scheduled_task_list2" in job_ids
    end

    test "returns empty list when no jobs exist" do
      assert {:ok, result} = ListScheduledTasks.run(%{}, %{})
      assert result.jobs == []
      assert result.count == 0
    end

    test "each job record contains expected fields" do
      ScheduledTaskStore.save(%{
        job_id: :scheduled_task_fields,
        schedule: "@daily",
        task: "daily report",
        room_id: "cli:main",
        mode: "isolated",
        created_at: "2026-02-15T00:00:00Z"
      })

      assert {:ok, result} = ListScheduledTasks.run(%{}, %{})
      [job] = result.jobs

      assert job["job_id"] == "scheduled_task_fields"
      assert job["schedule"] == "@daily"
      assert job["task"] == "daily report"
      assert job["room_id"] == "cli:main"
      assert job["created_at"] == "2026-02-15T00:00:00Z"
    end

    test "returns empty list when directory doesn't exist" do
      scheduled_task_dir = Path.join(@test_workspace, "scheduling/scheduled_tasks")
      File.rm_rf!(scheduled_task_dir)

      assert {:ok, result} = ListScheduledTasks.run(%{}, %{})
      assert result.jobs == []
      assert result.count == 0
    end
  end
end
