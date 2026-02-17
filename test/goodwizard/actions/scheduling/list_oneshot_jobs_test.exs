defmodule Goodwizard.Actions.Scheduling.ListOneShotJobsTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.ListOneShotJobs
  alias Goodwizard.Scheduling.OneShotStore

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "list_oneshot_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    ensure_config_started()

    oneshot_dir = Path.join(@test_workspace, "scheduling/oneshot")
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(oneshot_dir)

    original_workspace = Goodwizard.Config.workspace()
    Goodwizard.Config.put(["agent", "workspace"], @test_workspace)

    on_exit(fn ->
      File.rm_rf!(@test_workspace)

      if Process.whereis(Goodwizard.Config) do
        Goodwizard.Config.put(["agent", "workspace"], original_workspace)
      end
    end)

    :ok
  end

  defp ensure_config_started do
    if Process.whereis(Goodwizard.Config) do
      :ok
    else
      start_supervised!(Goodwizard.Config)
      :ok
    end
  end

  describe "run/2" do
    test "returns jobs sorted by fires_at ascending" do
      OneShotStore.save(%{
        job_id: :oneshot_aa11bb22cc33dd44,
        task: "second task",
        channel: "cli",
        external_id: "direct",
        fires_at: ~U[2026-04-01 12:00:00Z],
        created_at: "2026-02-15T01:00:00Z"
      })

      OneShotStore.save(%{
        job_id: :oneshot_ee55ff66aa77bb88,
        task: "first task",
        channel: "cli",
        external_id: "direct",
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
        job_id: :oneshot_1122334455667788,
        task: "check fields",
        channel: "telegram",
        external_id: "123456",
        fires_at: ~U[2026-05-01 15:30:00Z],
        created_at: "2026-02-15T00:00:00Z"
      })

      assert {:ok, %{jobs: [job], count: 1}} = ListOneShotJobs.run(%{}, %{})
      assert job["job_id"] == "oneshot_1122334455667788"
      assert job["task"] == "check fields"
      assert job["channel"] == "telegram"
      assert job["external_id"] == "123456"
      assert job["fires_at"] == "2026-05-01T15:30:00Z"
      assert job["created_at"] == "2026-02-15T00:00:00Z"
    end
  end
end
