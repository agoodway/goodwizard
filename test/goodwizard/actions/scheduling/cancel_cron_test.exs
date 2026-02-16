defmodule Goodwizard.Actions.Scheduling.CancelCronTest do
  use ExUnit.Case, async: true

  alias Goodwizard.Actions.Scheduling.CancelCron

  describe "run/2" do
    test "valid job_id converts to atom and emits CronCancel directive" do
      params = %{job_id: "cron_12345678"}
      assert {:ok, result, [directive]} = CancelCron.run(params, %{})
      assert %Jido.Agent.Directive.CronCancel{} = directive
      assert directive.job_id == :cron_12345678
      assert result.job_id == :cron_12345678
    end

    test "returns cancelled: true and atom job_id" do
      params = %{job_id: "cron_99887766"}
      assert {:ok, result, [_directive]} = CancelCron.run(params, %{})
      assert result.cancelled == true
      assert result.job_id == :cron_99887766
      assert is_atom(result.job_id)
    end

    test "nonexistent job_id still returns success (idempotent)" do
      params = %{job_id: "cron_does_not_exist"}
      assert {:ok, result, [directive]} = CancelCron.run(params, %{})
      assert result.cancelled == true
      assert directive.job_id == :cron_does_not_exist
    end
  end
end
