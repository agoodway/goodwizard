defmodule Goodwizard.Scheduling.OneShotStoreTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Scheduling.OneShotStore

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "oneshot_store_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    oneshot_dir = Path.join(@test_workspace, "scheduling/oneshot")
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(oneshot_dir)

    original_workspace = Goodwizard.Config.workspace()
    Goodwizard.Config.put(["agent", "workspace"], @test_workspace)

    on_exit(fn ->
      File.rm_rf!(@test_workspace)
      Goodwizard.Config.put(["agent", "workspace"], original_workspace)
    end)

    %{oneshot_dir: oneshot_dir}
  end

  describe "save/1" do
    test "writes a JSON file named by job_id", %{oneshot_dir: oneshot_dir} do
      record = %{
        job_id: :oneshot_abc123def4560001,
        task: "send report",
        room_id: "cli:main",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      assert :ok = OneShotStore.save(record)

      path = Path.join(oneshot_dir, "oneshot_abc123def4560001.json")
      assert File.exists?(path)

      {:ok, content} = File.read(path)
      {:ok, data} = Jason.decode(content)
      assert data["job_id"] == "oneshot_abc123def4560001"
      assert data["task"] == "send report"
      assert data["room_id"] == "cli:main"
      assert data["fires_at"] == "2026-03-01T09:00:00Z"
    end

    test "creates scheduling/oneshot/ directory if missing" do
      oneshot_dir = Path.join(@test_workspace, "scheduling/oneshot")
      File.rm_rf!(oneshot_dir)
      refute File.dir?(oneshot_dir)

      record = %{
        job_id: :oneshot_0000000000000002,
        task: "test",
        room_id: "cli:main",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      assert :ok = OneShotStore.save(record)
      assert File.dir?(oneshot_dir)
      assert File.exists?(Path.join(oneshot_dir, "oneshot_0000000000000002.json"))
    end

    test "overwrites existing file with same job_id", %{oneshot_dir: oneshot_dir} do
      record = %{
        job_id: :oneshot_0000000000000003,
        task: "v1",
        room_id: "r1",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      assert :ok = OneShotStore.save(record)

      updated = %{record | task: "v2"}
      assert :ok = OneShotStore.save(updated)

      {:ok, content} = File.read(Path.join(oneshot_dir, "oneshot_0000000000000003.json"))
      {:ok, data} = Jason.decode(content)
      assert data["task"] == "v2"
    end
  end

  describe "delete/1" do
    test "removes an existing job file", %{oneshot_dir: oneshot_dir} do
      record = %{
        job_id: :oneshot_0000000000000004,
        task: "t",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      OneShotStore.save(record)
      assert File.exists?(Path.join(oneshot_dir, "oneshot_0000000000000004.json"))

      assert :ok = OneShotStore.delete(:oneshot_0000000000000004)
      refute File.exists?(Path.join(oneshot_dir, "oneshot_0000000000000004.json"))
    end

    test "returns :ok for nonexistent job_id" do
      assert :ok = OneShotStore.delete(:oneshot_0000000000000005)
    end

    test "accepts string job_id" do
      record = %{
        job_id: :oneshot_0000000000000006,
        task: "t",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      OneShotStore.save(record)

      assert :ok = OneShotStore.delete("oneshot_0000000000000006")
    end
  end

  describe "list/0" do
    test "returns all persisted jobs sorted by fires_at" do
      OneShotStore.save(%{
        job_id: :oneshot_00000000000000a1,
        task: "second",
        room_id: "r",
        fires_at: ~U[2026-03-02 09:00:00Z],
        created_at: "2026-02-15T01:00:00Z"
      })

      OneShotStore.save(%{
        job_id: :oneshot_00000000000000a2,
        task: "first",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      })

      assert {:ok, jobs} = OneShotStore.list()
      assert length(jobs) == 2
      assert [first, second] = jobs
      assert first["task"] == "first"
      assert second["task"] == "second"
    end

    test "returns empty list when no jobs exist" do
      oneshot_dir = Path.join(@test_workspace, "scheduling/oneshot")
      File.rm_rf!(oneshot_dir)
      File.mkdir_p!(oneshot_dir)

      assert {:ok, []} = OneShotStore.list()
    end

    test "returns empty list when directory doesn't exist" do
      oneshot_dir = Path.join(@test_workspace, "scheduling/oneshot")
      File.rm_rf!(oneshot_dir)

      assert {:ok, []} = OneShotStore.list()
    end

    test "skips malformed JSON files", %{oneshot_dir: oneshot_dir} do
      OneShotStore.save(%{
        job_id: :oneshot_00000000000000b1,
        task: "ok",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      })

      File.write!(Path.join(oneshot_dir, "oneshot_00000000000000b2.json"), "not valid json {{{")

      assert {:ok, jobs} = OneShotStore.list()
      assert length(jobs) == 1
      assert hd(jobs)["job_id"] == "oneshot_00000000000000b1"
    end

    test "ignores non-JSON files", %{oneshot_dir: oneshot_dir} do
      OneShotStore.save(%{
        job_id: :oneshot_00000000000000c1,
        task: "t",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      })

      File.write!(Path.join(oneshot_dir, "readme.txt"), "ignore me")

      assert {:ok, jobs} = OneShotStore.list()
      assert length(jobs) == 1
    end
  end

  describe "load_all/0" do
    test "returns same result as list/0" do
      OneShotStore.save(%{
        job_id: :oneshot_00000000000000d1,
        task: "t",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      })

      assert OneShotStore.list() == OneShotStore.load_all()
    end
  end

  describe "validate_job_id/1" do
    test "rejects job_id with .." do
      assert {:error, :invalid_job_id} = OneShotStore.validate_job_id("../escape")
    end

    test "rejects job_id with /" do
      assert {:error, :invalid_job_id} = OneShotStore.validate_job_id("foo/bar")
    end

    test "rejects job_id with null byte" do
      assert {:error, :invalid_job_id} = OneShotStore.validate_job_id("foo\0bar")
    end

    test "rejects job_id exceeding 255 bytes" do
      long_id = String.duplicate("a", 256)
      assert {:error, :invalid_job_id} = OneShotStore.validate_job_id(long_id)
    end

    test "rejects empty job_id" do
      assert {:error, :invalid_job_id} = OneShotStore.validate_job_id("")
    end

    test "rejects non-matching format" do
      assert {:error, :invalid_job_id} = OneShotStore.validate_job_id("bad_prefix")
    end

    test "accepts valid oneshot job_id" do
      assert :ok = OneShotStore.validate_job_id("oneshot_aabbccdd11223344")
    end

    test "rejects delete with invalid job_id" do
      assert {:error, :invalid_job_id} = OneShotStore.delete("../etc/passwd")
    end
  end
end
