defmodule Goodwizard.Scheduling.OneTimeStoreTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Scheduling.OneTimeStore

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "one_time_store_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    ensure_config_started()

    one_time_dir = Path.join(@test_workspace, "scheduling/one_time")
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(one_time_dir)

    original_workspace = Goodwizard.Config.workspace()
    Goodwizard.Config.put(["agent", "workspace"], @test_workspace)

    on_exit(fn ->
      File.rm_rf!(@test_workspace)

      if Process.whereis(Goodwizard.Config) do
        Goodwizard.Config.put(["agent", "workspace"], original_workspace)
      end
    end)

    %{one_time_dir: one_time_dir}
  end

  defp ensure_config_started do
    if Process.whereis(Goodwizard.Config) do
      :ok
    else
      start_supervised!(Goodwizard.Config)
      :ok
    end
  end

  describe "save/1" do
    test "writes a JSON file named by job_id", %{one_time_dir: one_time_dir} do
      record = %{
        job_id: :one_time_abc123def4560001,
        task: "send report",
        room_id: "cli:main",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      assert :ok = OneTimeStore.save(record)

      path = Path.join(one_time_dir, "one_time_abc123def4560001.json")
      assert File.exists?(path)

      {:ok, content} = File.read(path)
      {:ok, data} = Jason.decode(content)
      assert data["job_id"] == "one_time_abc123def4560001"
      assert data["task"] == "send report"
      assert data["room_id"] == "cli:main"
      assert data["fires_at"] == "2026-03-01T09:00:00Z"
    end

    test "creates scheduling/one_time/ directory if missing" do
      one_time_dir = Path.join(@test_workspace, "scheduling/one_time")
      File.rm_rf!(one_time_dir)
      refute File.dir?(one_time_dir)

      record = %{
        job_id: :one_time_0000000000000002,
        task: "test",
        room_id: "cli:main",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      assert :ok = OneTimeStore.save(record)
      assert File.dir?(one_time_dir)
      assert File.exists?(Path.join(one_time_dir, "one_time_0000000000000002.json"))
    end

    test "overwrites existing file with same job_id", %{one_time_dir: one_time_dir} do
      record = %{
        job_id: :one_time_0000000000000003,
        task: "v1",
        room_id: "r1",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      assert :ok = OneTimeStore.save(record)

      updated = %{record | task: "v2"}
      assert :ok = OneTimeStore.save(updated)

      {:ok, content} = File.read(Path.join(one_time_dir, "one_time_0000000000000003.json"))
      {:ok, data} = Jason.decode(content)
      assert data["task"] == "v2"
    end
  end

  describe "delete/1" do
    test "removes an existing job file", %{one_time_dir: one_time_dir} do
      record = %{
        job_id: :one_time_0000000000000004,
        task: "t",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      OneTimeStore.save(record)
      assert File.exists?(Path.join(one_time_dir, "one_time_0000000000000004.json"))

      assert :ok = OneTimeStore.delete(:one_time_0000000000000004)
      refute File.exists?(Path.join(one_time_dir, "one_time_0000000000000004.json"))
    end

    test "returns :ok for nonexistent job_id" do
      assert :ok = OneTimeStore.delete(:one_time_0000000000000005)
    end

    test "accepts string job_id" do
      record = %{
        job_id: :one_time_0000000000000006,
        task: "t",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      OneTimeStore.save(record)

      assert :ok = OneTimeStore.delete("one_time_0000000000000006")
    end
  end

  describe "list/0" do
    test "returns all persisted jobs sorted by fires_at" do
      OneTimeStore.save(%{
        job_id: :one_time_00000000000000a1,
        task: "second",
        room_id: "r",
        fires_at: ~U[2026-03-02 09:00:00Z],
        created_at: "2026-02-15T01:00:00Z"
      })

      OneTimeStore.save(%{
        job_id: :one_time_00000000000000a2,
        task: "first",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      })

      assert {:ok, jobs} = OneTimeStore.list()
      assert length(jobs) == 2
      assert [first, second] = jobs
      assert first["task"] == "first"
      assert second["task"] == "second"
    end

    test "returns empty list when no jobs exist" do
      one_time_dir = Path.join(@test_workspace, "scheduling/one_time")
      File.rm_rf!(one_time_dir)
      File.mkdir_p!(one_time_dir)

      assert {:ok, []} = OneTimeStore.list()
    end

    test "returns empty list when directory doesn't exist" do
      one_time_dir = Path.join(@test_workspace, "scheduling/one_time")
      File.rm_rf!(one_time_dir)

      assert {:ok, []} = OneTimeStore.list()
    end

    test "skips malformed JSON files", %{one_time_dir: one_time_dir} do
      OneTimeStore.save(%{
        job_id: :one_time_00000000000000b1,
        task: "ok",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      })

      File.write!(Path.join(one_time_dir, "one_time_00000000000000b2.json"), "not valid json {{{")

      assert {:ok, jobs} = OneTimeStore.list()
      assert length(jobs) == 1
      assert hd(jobs)["job_id"] == "one_time_00000000000000b1"
    end

    test "ignores non-JSON files", %{one_time_dir: one_time_dir} do
      OneTimeStore.save(%{
        job_id: :one_time_00000000000000c1,
        task: "t",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      })

      File.write!(Path.join(one_time_dir, "readme.txt"), "ignore me")

      assert {:ok, jobs} = OneTimeStore.list()
      assert length(jobs) == 1
    end
  end

  describe "load_all/0" do
    test "returns same result as list/0" do
      OneTimeStore.save(%{
        job_id: :one_time_00000000000000d1,
        task: "t",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      })

      assert OneTimeStore.list() == OneTimeStore.load_all()
    end
  end

  describe "validate_job_id/1" do
    test "rejects job_id with .." do
      assert {:error, :invalid_job_id} = OneTimeStore.validate_job_id("../escape")
    end

    test "rejects job_id with /" do
      assert {:error, :invalid_job_id} = OneTimeStore.validate_job_id("foo/bar")
    end

    test "rejects job_id with null byte" do
      assert {:error, :invalid_job_id} = OneTimeStore.validate_job_id("foo\0bar")
    end

    test "rejects job_id exceeding 255 bytes" do
      long_id = String.duplicate("a", 256)
      assert {:error, :invalid_job_id} = OneTimeStore.validate_job_id(long_id)
    end

    test "rejects empty job_id" do
      assert {:error, :invalid_job_id} = OneTimeStore.validate_job_id("")
    end

    test "rejects non-matching format" do
      assert {:error, :invalid_job_id} = OneTimeStore.validate_job_id("bad_prefix")
    end

    test "accepts valid one_time job_id" do
      assert :ok = OneTimeStore.validate_job_id("one_time_aabbccdd11223344")
    end

    test "rejects delete with invalid job_id" do
      assert {:error, :invalid_job_id} = OneTimeStore.delete("../etc/passwd")
    end
  end
end
