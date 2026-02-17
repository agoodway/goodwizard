defmodule Goodwizard.Scheduling.OneShotLifecycleIntegrationTest do
  @moduledoc """
  Integration test for the full one-shot lifecycle:
  schedule -> persist -> reload -> cancel
  """
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.{CancelOneShot, OneShot}
  alias Goodwizard.Scheduling.{OneShotLoader, OneShotStore}

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "oneshot_lifecycle_test_#{System.unique_integer([:positive])}"
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

  test "full lifecycle: schedule, persist, list, reload, cancel", %{oneshot_dir: oneshot_dir} do
    # 1. Schedule a one-shot job
    params = %{delay_minutes: 60, task: "lifecycle test", room_id: "room_lifecycle"}
    context = %{agent_id: "test_agent"}
    assert {:ok, result} = OneShot.run(params, context)
    assert result.scheduled == true
    job_id = result.job_id
    job_id_str = to_string(job_id)

    # 2. Verify persistence
    path = Path.join(oneshot_dir, "#{job_id_str}.json")
    assert File.exists?(path)

    {:ok, content} = File.read(path)
    {:ok, data} = Jason.decode(content)
    assert data["agent_id"] == "test_agent"

    # 3. Verify listing
    assert {:ok, jobs} = OneShotStore.list()
    assert length(jobs) == 1
    assert hd(jobs)["job_id"] == job_id_str

    # 4. Reload from disk (simulating app restart)
    assert {:ok, count} = OneShotLoader.reload()
    assert count == 1

    # 5. Cancel the job
    assert {:ok, cancel_result} = CancelOneShot.run(%{job_id: job_id_str}, %{})
    assert cancel_result.cancelled == true

    # 6. Verify file deleted
    refute File.exists?(path)

    # 7. Verify listing is empty
    assert {:ok, []} = OneShotStore.list()
  end

  test "scheduling multiple jobs and cancelling one preserves others" do
    context = %{agent_id: "test_agent"}

    # Schedule two jobs
    assert {:ok, r1} =
             OneShot.run(%{delay_minutes: 60, task: "job one", room_id: "room_1"}, context)

    assert {:ok, r2} =
             OneShot.run(%{delay_minutes: 120, task: "job two", room_id: "room_1"}, context)

    assert {:ok, jobs} = OneShotStore.list()
    assert length(jobs) == 2

    # Cancel one
    CancelOneShot.run(%{job_id: to_string(r1.job_id)}, %{})

    # Other is preserved
    assert {:ok, remaining} = OneShotStore.list()
    assert length(remaining) == 1
    assert hd(remaining)["job_id"] == to_string(r2.job_id)

    # Cleanup
    CancelOneShot.run(%{job_id: to_string(r2.job_id)}, %{})
  end
end
