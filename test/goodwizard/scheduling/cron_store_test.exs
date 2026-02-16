defmodule Goodwizard.Scheduling.CronStoreTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Scheduling.CronStore

  @test_workspace Path.join(System.tmp_dir!(), "cron_store_test_#{System.unique_integer([:positive])}")

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

  describe "save/1" do
    test "writes a JSON file named by job_id", %{cron_dir: cron_dir} do
      record = %{
        job_id: :cron_abc123,
        schedule: "0 9 * * *",
        task: "daily report",
        room_id: "cli:main",
        created_at: "2026-02-15T00:00:00Z"
      }

      assert :ok = CronStore.save(record)

      path = Path.join(cron_dir, "cron_abc123.json")
      assert File.exists?(path)

      {:ok, content} = File.read(path)
      {:ok, data} = Jason.decode(content)
      assert data["job_id"] == "cron_abc123"
      assert data["schedule"] == "0 9 * * *"
      assert data["task"] == "daily report"
      assert data["room_id"] == "cli:main"
      assert data["created_at"] == "2026-02-15T00:00:00Z"
    end

    test "creates scheduling/cron/ directory if missing" do
      # Remove the directory
      cron_dir = Path.join(@test_workspace, "scheduling/cron")
      File.rm_rf!(cron_dir)
      refute File.dir?(cron_dir)

      record = %{
        job_id: :cron_newdir,
        schedule: "*/5 * * * *",
        task: "poll",
        room_id: "cli:main",
        created_at: "2026-02-15T00:00:00Z"
      }

      assert :ok = CronStore.save(record)
      assert File.dir?(cron_dir)
      assert File.exists?(Path.join(cron_dir, "cron_newdir.json"))
    end

    test "overwrites existing file with same job_id", %{cron_dir: cron_dir} do
      record = %{
        job_id: :cron_overwrite,
        schedule: "0 9 * * *",
        task: "v1",
        room_id: "r1",
        created_at: "2026-02-15T00:00:00Z"
      }

      assert :ok = CronStore.save(record)

      updated = %{record | task: "v2"}
      assert :ok = CronStore.save(updated)

      {:ok, content} = File.read(Path.join(cron_dir, "cron_overwrite.json"))
      {:ok, data} = Jason.decode(content)
      assert data["task"] == "v2"
    end
  end

  describe "delete/1" do
    test "removes an existing job file", %{cron_dir: cron_dir} do
      record = %{
        job_id: :cron_del,
        schedule: "0 9 * * *",
        task: "t",
        room_id: "r",
        created_at: "2026-02-15T00:00:00Z"
      }

      CronStore.save(record)
      assert File.exists?(Path.join(cron_dir, "cron_del.json"))

      assert :ok = CronStore.delete(:cron_del)
      refute File.exists?(Path.join(cron_dir, "cron_del.json"))
    end

    test "returns :ok for nonexistent job_id" do
      assert :ok = CronStore.delete(:cron_nonexistent)
    end

    test "accepts string job_id" do
      record = %{
        job_id: :cron_strarg,
        schedule: "0 9 * * *",
        task: "t",
        room_id: "r",
        created_at: "2026-02-15T00:00:00Z"
      }

      CronStore.save(record)

      assert :ok = CronStore.delete("cron_strarg")
    end
  end

  describe "list/0" do
    test "returns all persisted jobs sorted by created_at" do
      CronStore.save(%{
        job_id: :cron_b,
        schedule: "0 10 * * *",
        task: "second",
        room_id: "r",
        created_at: "2026-02-15T01:00:00Z"
      })

      CronStore.save(%{
        job_id: :cron_a,
        schedule: "0 9 * * *",
        task: "first",
        room_id: "r",
        created_at: "2026-02-15T00:00:00Z"
      })

      assert {:ok, jobs} = CronStore.list()
      assert length(jobs) == 2
      assert [first, second] = jobs
      assert first["task"] == "first"
      assert second["task"] == "second"
    end

    test "returns empty list when no jobs exist" do
      # Clear any existing files
      cron_dir = Path.join(@test_workspace, "scheduling/cron")
      File.rm_rf!(cron_dir)
      File.mkdir_p!(cron_dir)

      assert {:ok, []} = CronStore.list()
    end

    test "returns empty list when directory doesn't exist" do
      cron_dir = Path.join(@test_workspace, "scheduling/cron")
      File.rm_rf!(cron_dir)

      assert {:ok, []} = CronStore.list()
    end

    test "skips malformed JSON files", %{cron_dir: cron_dir} do
      CronStore.save(%{
        job_id: :cron_good,
        schedule: "0 9 * * *",
        task: "ok",
        room_id: "r",
        created_at: "2026-02-15T00:00:00Z"
      })

      File.write!(Path.join(cron_dir, "cron_bad.json"), "not valid json {{{")

      assert {:ok, jobs} = CronStore.list()
      assert length(jobs) == 1
      assert hd(jobs)["job_id"] == "cron_good"
    end

    test "ignores non-JSON files", %{cron_dir: cron_dir} do
      CronStore.save(%{
        job_id: :cron_only,
        schedule: "0 9 * * *",
        task: "t",
        room_id: "r",
        created_at: "2026-02-15T00:00:00Z"
      })

      File.write!(Path.join(cron_dir, "readme.txt"), "ignore me")

      assert {:ok, jobs} = CronStore.list()
      assert length(jobs) == 1
    end
  end

  describe "load_all/0" do
    test "returns same result as list/0" do
      CronStore.save(%{
        job_id: :cron_load,
        schedule: "0 9 * * *",
        task: "t",
        room_id: "r",
        created_at: "2026-02-15T00:00:00Z"
      })

      assert CronStore.list() == CronStore.load_all()
    end
  end
end
