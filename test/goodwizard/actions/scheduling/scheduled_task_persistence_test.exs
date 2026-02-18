defmodule Goodwizard.Actions.Scheduling.ScheduledTaskPersistenceTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.ScheduledTask

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "scheduled_task_persist_test_#{System.unique_integer([:positive])}"
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

  describe "persistence on schedule" do
    test "file is written after successful scheduling", %{scheduled_task_dir: scheduled_task_dir} do
      params = %{
        schedule: "0 9 * * *",
        task: "daily report",
        channel: "telegram",
        external_id: "123"
      }

      assert {:ok, result} = ScheduledTask.run(params, %{})

      job_id_str = to_string(result.job_id)
      path = Path.join(scheduled_task_dir, "#{job_id_str}.json")
      assert File.exists?(path)

      {:ok, content} = File.read(path)
      {:ok, data} = Jason.decode(content)
      assert data["schedule"] == "0 9 * * *"
      assert data["task"] == "daily report"
      assert data["channel"] == "telegram"
      assert data["external_id"] == "123"
      assert data["job_id"] == job_id_str
      assert is_binary(data["created_at"])
    end

    test "no file is written on validation failure", %{scheduled_task_dir: scheduled_task_dir} do
      params = %{schedule: "bad * * *", task: "test", channel: "cli", external_id: "direct"}
      assert {:error, _msg} = ScheduledTask.run(params, %{})

      {:ok, files} = File.ls(scheduled_task_dir)
      assert files == []
    end
  end
end
