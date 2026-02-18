defmodule Goodwizard.Scheduling.ScheduledTaskLoaderTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Scheduling.ScheduledTaskLoader
  alias Goodwizard.Scheduling.ScheduledTaskStore

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "scheduled_task_loader_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    ensure_goodwizard_started()
    ensure_config_started()
    ensure_jido_runtime_started()

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

  describe "reload/0" do
    test "reloads valid persisted jobs with channel targeting" do
      ScheduledTaskStore.save(%{
        job_id: :scheduled_task_aa11bb22cc33dd44,
        schedule: "0 9 * * *",
        task: "morning check",
        channel: "telegram",
        external_id: "123456",
        mode: "isolated",
        created_at: "2026-02-15T00:00:00Z"
      })

      ScheduledTaskStore.save(%{
        job_id: :scheduled_task_ee55ff66aa77bb88,
        schedule: "*/5 * * * *",
        task: "poll status",
        channel: "cli",
        external_id: "direct",
        mode: "main",
        created_at: "2026-02-15T01:00:00Z"
      })

      assert {:ok, 2} = ScheduledTaskLoader.reload()
    end

    test "reloads legacy jobs with room_id" do
      ScheduledTaskStore.save(%{
        job_id: :scheduled_task_aa11bb22cc33dd44,
        schedule: "0 9 * * *",
        task: "legacy task",
        room_id: "cli:main",
        mode: "isolated",
        created_at: "2026-02-15T00:00:00Z"
      })

      assert {:ok, 1} = ScheduledTaskLoader.reload()
    end

    test "returns zero for empty directory" do
      assert {:ok, 0} = ScheduledTaskLoader.reload()
    end

    test "returns zero when directory doesn't exist" do
      scheduled_task_dir = Path.join(@test_workspace, "scheduling/scheduled_tasks")
      File.rm_rf!(scheduled_task_dir)

      assert {:ok, 0} = ScheduledTaskLoader.reload()
    end

    test "skips malformed files and continues", %{scheduled_task_dir: scheduled_task_dir} do
      ScheduledTaskStore.save(%{
        job_id: :scheduled_task_1122334455667788,
        schedule: "0 9 * * *",
        task: "valid task",
        channel: "cli",
        external_id: "direct",
        mode: "isolated",
        created_at: "2026-02-15T00:00:00Z"
      })

      # Write a malformed JSON file — ScheduledTaskStore.list skips it
      File.write!(Path.join(scheduled_task_dir, "scheduled_task_bad.json"), "not valid json {{{")

      assert {:ok, 1} = ScheduledTaskLoader.reload()
    end

    test "skips jobs with missing required fields", %{scheduled_task_dir: scheduled_task_dir} do
      # Write a valid JSON file that's missing the "schedule" field
      incomplete_job = %{
        "job_id" => "scheduled_task_incomplete",
        "task" => "no schedule",
        "created_at" => "2026-02-15T00:00:00Z"
      }

      File.write!(
        Path.join(scheduled_task_dir, "scheduled_task_incomplete.json"),
        Jason.encode!(incomplete_job)
      )

      # Also add a valid job
      ScheduledTaskStore.save(%{
        job_id: :scheduled_task_aabbccdd11223344,
        schedule: "0 9 * * *",
        task: "has schedule",
        channel: "cli",
        external_id: "direct",
        mode: "isolated",
        created_at: "2026-02-15T00:00:00Z"
      })

      assert {:ok, 1} = ScheduledTaskLoader.reload()
    end

    test "handles reload with model override" do
      ScheduledTaskStore.save(%{
        job_id: :scheduled_task_99887766aabbccdd,
        schedule: "@daily",
        task: "daily report",
        channel: "cli",
        external_id: "direct",
        mode: "isolated",
        model: "anthropic:claude-haiku-4-5",
        created_at: "2026-02-15T00:00:00Z"
      })

      assert {:ok, 1} = ScheduledTaskLoader.reload()
    end
  end
end
