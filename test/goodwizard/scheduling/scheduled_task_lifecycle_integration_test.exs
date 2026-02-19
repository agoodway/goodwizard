defmodule Goodwizard.Scheduling.CronLifecycleIntegrationTest do
  @moduledoc """
  Integration test for the full cron lifecycle:
  schedule -> persist -> reload -> cancel
  """
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.{CancelScheduledTask, ScheduledTask}
  alias Goodwizard.Scheduling.{ScheduledTaskLoader, ScheduledTaskStore}

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "scheduled_task_lifecycle_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    ensure_goodwizard_started()
    ensure_config_started()
    ensure_scheduled_task_registry_started()
    ensure_jido_runtime_started()

    scheduled_task_dir = Path.join(@test_workspace, "scheduling/scheduled_tasks")
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(scheduled_task_dir)

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

  defp ensure_goodwizard_started do
    case Application.ensure_all_started(:goodwizard) do
      {:ok, _apps} -> :ok
      {:error, reason} -> raise "failed to start :goodwizard for test: #{inspect(reason)}"
    end
  end

  defp ensure_jido_runtime_started do
    ensure_registry_started()
    ensure_task_supervisor_started()
    ensure_agent_supervisor_started()
    :ok
  end

  defp ensure_registry_started do
    if Process.whereis(Goodwizard.Jido.Registry) do
      :ok
    else
      start_supervised!({Registry, keys: :unique, name: Goodwizard.Jido.Registry})
      :ok
    end
  end

  defp ensure_task_supervisor_started do
    name = Goodwizard.Jido.task_supervisor_name()

    if Process.whereis(name) do
      :ok
    else
      start_supervised!({Task.Supervisor, name: name})
      :ok
    end
  end

  defp ensure_agent_supervisor_started do
    if Process.whereis(Goodwizard.Jido.AgentSupervisor) do
      :ok
    else
      start_supervised!(
        {DynamicSupervisor, strategy: :one_for_one, name: Goodwizard.Jido.AgentSupervisor}
      )

      :ok
    end
  end

  test "full lifecycle: schedule, persist, list, reload, cancel", %{
    scheduled_task_dir: scheduled_task_dir
  } do
    # 1. Schedule a scheduled task
    params = %{
      schedule: "0 9 * * *",
      task: "lifecycle test",
      channel: "cli",
      external_id: "direct"
    }

    assert {:ok, result} = ScheduledTask.run(params, %{})
    assert result.scheduled == true
    job_id = result.job_id
    job_id_str = to_string(job_id)

    # 2. Verify persistence
    path = Path.join(scheduled_task_dir, "#{job_id_str}.json")
    assert File.exists?(path)

    # 3. Verify listing
    assert {:ok, jobs} = ScheduledTaskStore.list()
    assert length(jobs) == 1
    assert hd(jobs)["job_id"] == job_id_str

    # 4. Reload from disk (simulating app restart)
    assert {:ok, count} = ScheduledTaskLoader.reload()
    assert count == 1

    # 5. Cancel the job
    assert {:ok, cancel_result} = CancelScheduledTask.run(%{job_id: job_id_str}, %{})
    assert cancel_result.cancelled == true

    # 6. Verify file deleted
    refute File.exists?(path)

    # 7. Verify listing is empty
    assert {:ok, []} = ScheduledTaskStore.list()
  end

  test "scheduling multiple jobs and cancelling one preserves others" do
    # Schedule two jobs
    assert {:ok, r1} =
             ScheduledTask.run(
               %{schedule: "0 9 * * *", task: "job one", channel: "cli", external_id: "direct"},
               %{}
             )

    assert {:ok, r2} =
             ScheduledTask.run(
               %{schedule: "0 10 * * *", task: "job two", channel: "cli", external_id: "direct"},
               %{}
             )

    assert {:ok, jobs} = ScheduledTaskStore.list()
    assert length(jobs) == 2

    # Cancel one
    CancelScheduledTask.run(%{job_id: to_string(r1.job_id)}, %{})

    # Other is preserved
    assert {:ok, remaining} = ScheduledTaskStore.list()
    assert length(remaining) == 1
    assert hd(remaining)["job_id"] == to_string(r2.job_id)
  end
end
