defmodule Goodwizard.Scheduling.CronLoaderTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Scheduling.CronLoader
  alias Goodwizard.Scheduling.CronStore

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "cron_loader_test_#{System.unique_integer([:positive])}"
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

  describe "reload/0" do
    test "reloads valid persisted jobs" do
      CronStore.save(%{
        job_id: :cron_reload1,
        schedule: "0 9 * * *",
        task: "morning check",
        room_id: "cli:main",
        mode: "isolated",
        created_at: "2026-02-15T00:00:00Z"
      })

      CronStore.save(%{
        job_id: :cron_reload2,
        schedule: "*/5 * * * *",
        task: "poll status",
        room_id: "cli:heartbeat",
        mode: "main",
        created_at: "2026-02-15T01:00:00Z"
      })

      assert {:ok, 2} = CronLoader.reload()
    end

    test "returns zero for empty directory" do
      assert {:ok, 0} = CronLoader.reload()
    end

    test "returns zero when directory doesn't exist" do
      cron_dir = Path.join(@test_workspace, "scheduling/cron")
      File.rm_rf!(cron_dir)

      assert {:ok, 0} = CronLoader.reload()
    end

    test "skips malformed files and continues", %{cron_dir: cron_dir} do
      CronStore.save(%{
        job_id: :cron_good_reload,
        schedule: "0 9 * * *",
        task: "valid task",
        room_id: "cli:main",
        mode: "isolated",
        created_at: "2026-02-15T00:00:00Z"
      })

      # Write a malformed JSON file — CronStore.list skips it
      File.write!(Path.join(cron_dir, "cron_bad.json"), "not valid json {{{")

      assert {:ok, 1} = CronLoader.reload()
    end

    test "skips jobs with missing required fields", %{cron_dir: cron_dir} do
      # Write a valid JSON file that's missing the "schedule" field
      incomplete_job = %{
        "job_id" => "cron_incomplete",
        "task" => "no schedule",
        "created_at" => "2026-02-15T00:00:00Z"
      }

      File.write!(Path.join(cron_dir, "cron_incomplete.json"), Jason.encode!(incomplete_job))

      # Also add a valid job
      CronStore.save(%{
        job_id: :cron_complete,
        schedule: "0 9 * * *",
        task: "has schedule",
        room_id: "cli:main",
        mode: "isolated",
        created_at: "2026-02-15T00:00:00Z"
      })

      assert {:ok, 1} = CronLoader.reload()
    end

    test "handles reload with model override" do
      CronStore.save(%{
        job_id: :cron_with_model,
        schedule: "@daily",
        task: "daily report",
        room_id: "cli:main",
        mode: "isolated",
        model: "anthropic:claude-haiku-4-5",
        created_at: "2026-02-15T00:00:00Z"
      })

      assert {:ok, 1} = CronLoader.reload()
    end
  end
end
