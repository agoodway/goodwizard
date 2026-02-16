defmodule Goodwizard.Actions.Scheduling.CancelCronTest do
  use ExUnit.Case, async: false

  alias Goodwizard.Actions.Scheduling.CancelCron
  alias Goodwizard.Scheduling.CronStore

  @test_workspace Path.join(
                    System.tmp_dir!(),
                    "cancel_cron_test_#{System.unique_integer([:positive])}"
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

  describe "run/2" do
    test "cancels existing job: deletes file and emits CronCancel directive", %{cron_dir: cron_dir} do
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
      assert {:ok, result, [directive]} = CancelCron.run(params, %{})
      assert %Jido.Agent.Directive.CronCancel{} = directive
      assert directive.job_id == :cron_cancel_me
      assert result.cancelled == true

      refute File.exists?(Path.join(cron_dir, "cron_cancel_me.json"))
    end

    test "unknown job_id still emits cancel directive and returns success" do
      params = %{job_id: "cron_does_not_exist_at_all"}
      assert {:ok, result, [directive]} = CancelCron.run(params, %{})
      assert %Jido.Agent.Directive.CronCancel{} = directive
      assert result.cancelled == true
    end

    test "returns atom job_id in result" do
      params = %{job_id: "cron_99887766"}
      assert {:ok, result, [_directive]} = CancelCron.run(params, %{})
      assert is_atom(result.job_id)
    end
  end
end
