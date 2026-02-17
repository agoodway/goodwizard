defmodule Goodwizard.Actions.Scheduling.CancelCronTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.CancelCron
  alias Goodwizard.Scheduling.CronStore

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "cancel_cron_test_#{System.unique_integer([:positive])}"
                  )

  setup do
    ensure_config_started()
    ensure_cron_registry_started()

    cron_dir = Path.join(@test_workspace, "scheduling/cron")
    File.rm_rf!(@test_workspace)
    File.mkdir_p!(cron_dir)

    # Save original workspace and override it for tests
    original_workspace = Goodwizard.Config.workspace()
    Goodwizard.Config.put(["agent", "workspace"], @test_workspace)

    on_exit(fn ->
      File.rm_rf!(@test_workspace)

      if Process.whereis(Goodwizard.Config) do
        Goodwizard.Config.put(["agent", "workspace"], original_workspace)
      end
    end)

    %{cron_dir: cron_dir}
  end

  defp ensure_config_started do
    if Process.whereis(Goodwizard.Config) do
      :ok
    else
      start_supervised!(Goodwizard.Config)
      :ok
    end
  end

  defp ensure_cron_registry_started do
    if Process.whereis(Goodwizard.Scheduling.CronRegistry) do
      :ok
    else
      start_supervised!(Goodwizard.Scheduling.CronRegistry)
      :ok
    end
  end

  describe "run/2" do
    test "cancels existing job: deletes file and returns success", %{cron_dir: cron_dir} do
      # Persist a job first
      CronStore.save(%{
        job_id: :cron_cancel_me,
        schedule: "0 9 * * *",
        task: "test task",
        room_id: "cli:main",
        created_at: "2026-02-15T00:00:00Z"
      })

      assert File.exists?(Path.join(cron_dir, "cron_cancel_me.json"))

      params = %{job_id: "cron_cancel_me"}
      assert {:ok, result} = CancelCron.run(params, %{})
      assert result.cancelled == true

      refute File.exists?(Path.join(cron_dir, "cron_cancel_me.json"))
    end

    test "unknown job_id still returns success (idempotent)" do
      params = %{job_id: "cron_does_not_exist_at_all"}
      assert {:ok, result} = CancelCron.run(params, %{})
      assert result.cancelled == true
    end

    test "returns atom job_id when atom exists, string otherwise" do
      # This atom exists because it was created via the Cron action or test setup
      _ = :cron_existing_test_atom
      params = %{job_id: "cron_existing_test_atom"}
      assert {:ok, result} = CancelCron.run(params, %{})
      assert result.job_id == :cron_existing_test_atom

      # For a never-seen job_id, falls back to string (no atom leak)
      params2 = %{job_id: "cron_never_seen_before_xyz"}
      assert {:ok, result2} = CancelCron.run(params2, %{})
      assert is_binary(result2.job_id)
    end
  end
end
