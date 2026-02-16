defmodule Goodwizard.Actions.Scheduling.CronPersistenceTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.Cron

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "cron_persist_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    cron_dir = Path.join(@test_workspace, "scheduling/cron")
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(cron_dir)

    # Save original workspace and override it for tests
    original_workspace = Goodwizard.Config.workspace()
    Goodwizard.Config.put(["agent", "workspace"], @test_workspace)

    on_exit(fn ->
      File.rm_rf!(@test_workspace)
      Goodwizard.Config.put(["agent", "workspace"], original_workspace)
    end)

    %{cron_dir: cron_dir}
  end

  describe "persistence on schedule" do
    test "file is written after successful scheduling", %{cron_dir: cron_dir} do
      params = %{schedule: "0 9 * * *", task: "daily report", room_id: "cli:heartbeat"}
      assert {:ok, result, [_directive]} = Cron.run(params, %{})

      job_id_str = to_string(result.job_id)
      path = Path.join(cron_dir, "#{job_id_str}.json")
      assert File.exists?(path)

      {:ok, content} = File.read(path)
      {:ok, data} = Jason.decode(content)
      assert data["schedule"] == "0 9 * * *"
      assert data["task"] == "daily report"
      assert data["room_id"] == "cli:heartbeat"
      assert data["job_id"] == job_id_str
      assert is_binary(data["created_at"])
    end

    test "no file is written on validation failure", %{cron_dir: cron_dir} do
      params = %{schedule: "bad * * *", task: "test", room_id: "cli:main"}
      assert {:error, _msg} = Cron.run(params, %{})

      {:ok, files} = File.ls(cron_dir)
      assert files == []
    end
  end
end
