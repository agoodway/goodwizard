defmodule Goodwizard.Actions.Scheduling.ListOneShotJobsTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.ListOneShotJobs
  alias Goodwizard.Scheduling.OneShotStore

  @test_workspace Path.join(System.tmp_dir!(), "list_oneshot_test_#{System.unique_integer([:positive])}")

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

    :ok
  end

  describe "run/2" do
    test "returns jobs sorted by fires_at ascending" do
      OneShotStore.save(%{
        job_id: :oneshot_list_later00000,
        task: "second task",
        room_id: "cli:main",
        fires_at: ~U[2026-04-01 12:00:00Z],
        created_at: "2026-02-15T01:00:00Z"
      })

      OneShotStore.save(%{
        job_id: :oneshot_list_earlier000,
        task: "first task",
        room_id: "cli:main",
        fires_at: ~U[2026-03-01 09:00:00Z],
        created_at: "2026-02-15T00:00:00Z"
      })

      assert {:ok, %{jobs: jobs, count: 2}} = ListOneShotJobs.run(%{}, %{})
      assert [first, second] = jobs
      assert first["task"] == "first task"
      assert second["task"] == "second task"
    end

    test "returns empty list when no jobs exist" do
      assert {:ok, %{jobs: [], count: 0}} = ListOneShotJobs.run(%{}, %{})
    end

    test "includes all job fields" do
      OneShotStore.save(%{
        job_id: :oneshot_list_fields000,
        task: "check fields",
        room_id: "telegram:main",
        fires_at: ~U[2026-05-01 15:30:00Z],
        created_at: "2026-02-15T00:00:00Z"
      })

      assert {:ok, %{jobs: [job], count: 1}} = ListOneShotJobs.run(%{}, %{})
      assert job["job_id"] == "oneshot_list_fields000"
      assert job["task"] == "check fields"
      assert job["room_id"] == "telegram:main"
      assert job["fires_at"] == "2026-05-01T15:30:00Z"
      assert job["created_at"] == "2026-02-15T00:00:00Z"
    end
  end
end
