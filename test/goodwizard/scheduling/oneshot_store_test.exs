defmodule Goodwizard.Scheduling.OneShotStoreTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Scheduling.OneShotStore

  @test_workspace Path.join(System.tmp_dir!(), "oneshot_store_test_#{System.unique_integer([:positive])}")

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
        job_id: :oneshot_abc123def45678,
        task: "send report",
        room_id: "cli:main",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      assert :ok = OneShotStore.save(record)

      path = Path.join(oneshot_dir, "oneshot_abc123def45678.json")
      assert File.exists?(path)

      {:ok, content} = File.read(path)
      {:ok, data} = Jason.decode(content)
      assert data["job_id"] == "oneshot_abc123def45678"
      assert data["task"] == "send report"
      assert data["room_id"] == "cli:main"
      assert data["fires_at"] == "2026-03-01T09:00:00Z"
    end

    test "creates scheduling/oneshot/ directory if missing" do
      oneshot_dir = Path.join(@test_workspace, "scheduling/oneshot")
      File.rm_rf!(oneshot_dir)
      refute File.dir?(oneshot_dir)

      record = %{
        job_id: :oneshot_newdir0000000,
        task: "test",
        room_id: "cli:main",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      assert :ok = OneShotStore.save(record)
      assert File.dir?(oneshot_dir)
      assert File.exists?(Path.join(oneshot_dir, "oneshot_newdir0000000.json"))
    end

    test "overwrites existing file with same job_id", %{oneshot_dir: oneshot_dir} do
      record = %{
        job_id: :oneshot_overwrite00000,
        task: "v1",
        room_id: "r1",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      assert :ok = OneShotStore.save(record)

      updated = %{record | task: "v2"}
      assert :ok = OneShotStore.save(updated)

      {:ok, content} = File.read(Path.join(oneshot_dir, "oneshot_overwrite00000.json"))
      {:ok, data} = Jason.decode(content)
      assert data["task"] == "v2"
    end
  end

  describe "delete/1" do
    test "removes an existing job file", %{oneshot_dir: oneshot_dir} do
      record = %{
        job_id: :oneshot_del000000000,
        task: "t",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      OneShotStore.save(record)
      assert File.exists?(Path.join(oneshot_dir, "oneshot_del000000000.json"))

      assert :ok = OneShotStore.delete(:oneshot_del000000000)
      refute File.exists?(Path.join(oneshot_dir, "oneshot_del000000000.json"))
    end

    test "returns :ok for nonexistent job_id" do
      assert :ok = OneShotStore.delete(:oneshot_nonexistent0)
    end

    test "accepts string job_id" do
      record = %{
        job_id: :oneshot_strarg0000000,
        task: "t",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      OneShotStore.save(record)

      assert :ok = OneShotStore.delete("oneshot_strarg0000000")
    end
  end

  describe "list/0" do
    test "returns all persisted jobs sorted by fires_at" do
      OneShotStore.save(%{
        job_id: :oneshot_later00000000,
        task: "second",
        room_id: "r",
        fires_at: ~U[2026-03-02 09:00:00Z],
        created_at: "2026-02-15T01:00:00Z"
      })

      OneShotStore.save(%{
        job_id: :oneshot_earlier000000,
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
        job_id: :oneshot_good00000000,
        task: "ok",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      })

      File.write!(Path.join(oneshot_dir, "oneshot_bad.json"), "not valid json {{{")

      assert {:ok, jobs} = OneShotStore.list()
      assert length(jobs) == 1
      assert hd(jobs)["job_id"] == "oneshot_good00000000"
    end

    test "ignores non-JSON files", %{oneshot_dir: oneshot_dir} do
      OneShotStore.save(%{
        job_id: :oneshot_only00000000,
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
        job_id: :oneshot_load00000000,
        task: "t",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      })

      assert OneShotStore.list() == OneShotStore.load_all()
    end
  end

  describe "path traversal prevention" do
    test "rejects job_id with .." do
      record = %{
        job_id: :"../escape",
        task: "t",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      assert {:error, :path_traversal} = OneShotStore.save(record)
    end

    test "rejects job_id with /" do
      record = %{
        job_id: :"foo/bar",
        task: "t",
        room_id: "r",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      }

      assert {:error, :path_traversal} = OneShotStore.save(record)
    end

    test "rejects job_id with null byte" do
      assert {:error, :path_traversal} = OneShotStore.validate_job_id("foo\0bar")
    end

    test "rejects job_id exceeding 255 bytes" do
      long_id = String.duplicate("a", 256)
      assert {:error, :invalid_job_id} = OneShotStore.validate_job_id(long_id)
    end

    test "rejects empty job_id" do
      assert {:error, :invalid_job_id} = OneShotStore.validate_job_id("")
    end

    test "rejects delete with path traversal" do
      assert {:error, :path_traversal} = OneShotStore.delete("../etc/passwd")
    end
  end
end
