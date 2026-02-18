defmodule Goodwizard.Actions.Scheduling.CancelScheduledTaskTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.CancelScheduledTask
  alias Goodwizard.Scheduling.ScheduledTaskStore

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "cancel_scheduled_task_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    ensure_config_started()
    ensure_scheduled_task_registry_started()

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

  defp ensure_scheduled_task_registry_started do
    if Process.whereis(Goodwizard.Scheduling.ScheduledTaskRegistry) do
      :ok
    else
      start_supervised!(Goodwizard.Scheduling.ScheduledTaskRegistry)
      :ok
    end
  end

  describe "run/2" do
    test "cancels existing job: deletes file and returns success", %{
      scheduled_task_dir: scheduled_task_dir
    } do
      # Persist a job first
      ScheduledTaskStore.save(%{
        job_id: :scheduled_task_cancel_me,
        schedule: "0 9 * * *",
        task: "test task",
        room_id: "cli:main",
        created_at: "2026-02-15T00:00:00Z"
      })

      assert File.exists?(Path.join(scheduled_task_dir, "scheduled_task_cancel_me.json"))

      params = %{job_id: "scheduled_task_cancel_me"}
      assert {:ok, result} = CancelScheduledTask.run(params, %{})
      assert result.cancelled == true

      refute File.exists?(Path.join(scheduled_task_dir, "scheduled_task_cancel_me.json"))
    end

    test "unknown job_id still returns success (idempotent)" do
      params = %{job_id: "scheduled_task_does_not_exist_at_all"}
      assert {:ok, result} = CancelScheduledTask.run(params, %{})
      assert result.cancelled == true
    end

    test "returns atom job_id when atom exists, string otherwise" do
      # This atom exists because it was created via the Scheduled task action or test setup
      _ = :scheduled_task_existing_test_atom
      params = %{job_id: "scheduled_task_existing_test_atom"}
      assert {:ok, result} = CancelScheduledTask.run(params, %{})
      assert result.job_id == :scheduled_task_existing_test_atom

      # For a never-seen job_id, falls back to string (no atom leak)
      params2 = %{job_id: "scheduled_task_never_seen_before_xyz"}
      assert {:ok, result2} = CancelScheduledTask.run(params2, %{})
      assert is_binary(result2.job_id)
    end
  end
end
