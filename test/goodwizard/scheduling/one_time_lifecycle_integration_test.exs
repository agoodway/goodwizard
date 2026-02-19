defmodule Goodwizard.Scheduling.OneTimeLifecycleIntegrationTest do
  @moduledoc """
  Integration test for the full one-time task lifecycle:
  schedule -> persist -> reload -> cancel
  """
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.{CancelOneTime, OneTime}
  alias Goodwizard.Scheduling.{OneTimeLoader, OneTimeStore}

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "one_time_lifecycle_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    ensure_goodwizard_started()
    ensure_config_started()
    ensure_one_time_registry_started()

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

  defp ensure_goodwizard_started do
    case Application.ensure_all_started(:goodwizard) do
      {:ok, _apps} -> :ok
      {:error, reason} -> raise "failed to start :goodwizard for test: #{inspect(reason)}"
    end
  end

  defp ensure_one_time_registry_started do
    if Process.whereis(Goodwizard.Scheduling.OneTimeRegistry) do
      :ok
    else
      start_supervised!(Goodwizard.Scheduling.OneTimeRegistry)
      :ok
    end
  end

  test "full lifecycle: schedule, persist, list, reload, cancel", %{one_time_dir: one_time_dir} do
    # 1. Schedule a one-time task
    params = %{delay_minutes: 60, task: "lifecycle test", channel: "cli", external_id: "direct"}
    context = %{agent_id: "test_agent"}
    assert {:ok, result} = OneTime.run(params, context)
    assert result.scheduled == true
    job_id = result.job_id
    job_id_str = to_string(job_id)

    # 2. Verify persistence
    path = Path.join(one_time_dir, "#{job_id_str}.json")
    assert File.exists?(path)

    {:ok, content} = File.read(path)
    {:ok, data} = Jason.decode(content)
    assert data["agent_id"] == "test_agent"

    # 3. Verify listing
    assert {:ok, jobs} = OneTimeStore.list()
    assert length(jobs) == 1
    assert hd(jobs)["job_id"] == job_id_str

    # 4. Reload from disk (simulating app restart)
    assert {:ok, count} = OneTimeLoader.reload()
    assert count == 1

    # 5. Cancel the job
    assert {:ok, cancel_result} = CancelOneTime.run(%{job_id: job_id_str}, %{})
    assert cancel_result.cancelled == true

    # 6. Verify file deleted
    refute File.exists?(path)

    # 7. Verify listing is empty
    assert {:ok, []} = OneTimeStore.list()
  end

  test "scheduling multiple jobs and cancelling one preserves others" do
    context = %{agent_id: "test_agent"}

    # Schedule two jobs
    assert {:ok, r1} =
             OneTime.run(
               %{delay_minutes: 60, task: "job one", channel: "cli", external_id: "direct"},
               context
             )

    assert {:ok, r2} =
             OneTime.run(
               %{delay_minutes: 120, task: "job two", channel: "cli", external_id: "direct"},
               context
             )

    assert {:ok, jobs} = OneTimeStore.list()
    assert length(jobs) == 2

    # Cancel one
    CancelOneTime.run(%{job_id: to_string(r1.job_id)}, %{})

    # Other is preserved
    assert {:ok, remaining} = OneTimeStore.list()
    assert length(remaining) == 1
    assert hd(remaining)["job_id"] == to_string(r2.job_id)

    # Cleanup
    CancelOneTime.run(%{job_id: to_string(r2.job_id)}, %{})
  end
end
